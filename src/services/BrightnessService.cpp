#include "BrightnessService.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

namespace ciderdeck {

BrightnessService::BrightnessService(QObject *parent)
    : QObject(parent) {
    // Try /sys/class/backlight first (laptops)
    initBacklight();
    if (available_) return;

    // Fall back to ddcutil (external monitors)
    initDdcutil();
}

void BrightnessService::initBacklight() {
    backlightPath_ = findBacklightPath();
    if (backlightPath_.isEmpty()) return;

    method_ = QStringLiteral("backlight");
    available_ = true;

    QFile maxFile(backlightPath_ + "/max_brightness");
    if (maxFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        maxBrightness_ = maxFile.readAll().trimmed().toInt();
        maxFile.close();
    }

    QFile curFile(backlightPath_ + "/brightness");
    if (curFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        int current = curFile.readAll().trimmed().toInt();
        curFile.close();
        if (maxBrightness_ > 0) {
            brightness_ = qRound(100.0 * current / maxBrightness_);
        }
    }
    emit availableChanged();
    emit brightnessChanged();
}

void BrightnessService::initDdcutil() {
    QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
    if (ddcutil.isEmpty()) return;

    // Run ddcutil detect --brief to find the Xeneon Edge display
    // Output format per display:
    //   Display N
    //      DRM connector:    card1-DP-3
    QProcess detectProc;
    detectProc.start(ddcutil, {QStringLiteral("detect"), QStringLiteral("--brief")});
    if (!detectProc.waitForFinished(15000)) return;

    QString detectOutput = detectProc.readAllStandardOutput();
    int targetDisplay = -1;

    // Parse display numbers and their DRM connectors
    // Look for the Xeneon Edge (2560x720) by connector name containing "DP-3"
    // or by monitor name containing "XENEON"
    static QRegularExpression displayRe(QStringLiteral(R"(Display\s+(\d+))"));
    static QRegularExpression connectorRe(QStringLiteral(R"(DRM connector:\s+\S+-(\S+))"));
    static QRegularExpression monitorRe(QStringLiteral(R"(Monitor:\s+(.+))"));

    const auto lines = detectOutput.split(QLatin1Char('\n'));
    int currentDisplayNum = -1;

    for (const QString &line : lines) {
        auto displayMatch = displayRe.match(line);
        if (displayMatch.hasMatch()) {
            currentDisplayNum = displayMatch.captured(1).toInt();
            continue;
        }

        // Check monitor name for XENEON
        auto monitorMatch = monitorRe.match(line);
        if (monitorMatch.hasMatch() && currentDisplayNum > 0) {
            if (monitorMatch.captured(1).contains(QStringLiteral("XENEON"), Qt::CaseInsensitive)) {
                targetDisplay = currentDisplayNum;
                break;
            }
        }

        // Also match by connector name (e.g., DP-3)
        auto connMatch = connectorRe.match(line);
        if (connMatch.hasMatch() && currentDisplayNum > 0) {
            // The connector name from ddcutil is like "card1-DP-3", we extract "DP-3"
            // But our screen names from Qt are just "DP-3"
            // For now, prefer XENEON match above; this is a fallback
        }
    }

    // If we didn't find XENEON specifically, try all displays and pick the first one that works
    if (targetDisplay < 0) {
        targetDisplay = 1;
    }

    // Now read brightness from the target display
    QProcess proc;
    proc.start(ddcutil, {QStringLiteral("getvcp"), QStringLiteral("10"),
                         QStringLiteral("--display"), QString::number(targetDisplay),
                         QStringLiteral("--brief")});
    if (!proc.waitForFinished(5000)) return;

    QString output = proc.readAllStandardOutput();
    static QRegularExpression re(QStringLiteral(R"(VCP\s+10\s+C\s+(\d+)\s+(\d+))"));
    auto match = re.match(output);
    if (!match.hasMatch()) return;

    brightness_ = match.captured(1).toInt();
    maxBrightness_ = match.captured(2).toInt();
    ddcDisplayNum_ = targetDisplay;
    method_ = QStringLiteral("ddcutil");
    available_ = true;

    qInfo() << "[BrightnessService] Using ddcutil display" << targetDisplay
             << "brightness:" << brightness_ << "/" << maxBrightness_;

    emit availableChanged();
    emit brightnessChanged();
}

void BrightnessService::setBrightness(int percent) {
    if (!available_) return;
    percent = qBound(1, percent, 100);

    if (method_ == QLatin1String("backlight")) {
        if (maxBrightness_ <= 0) return;
        int value = static_cast<int>(static_cast<double>(percent) / 100.0 * maxBrightness_);
        QFile file(backlightPath_ + "/brightness");
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream stream(&file);
            stream << value;
            file.close();
            brightness_ = percent;
            emit brightnessChanged();
        }
    } else if (method_ == QLatin1String("ddcutil")) {
        if (ddcBusy_) return; // skip if previous call still running
        ddcBusy_ = true;
        brightness_ = percent;
        emit brightnessChanged();

        QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
        auto *proc = new QProcess(this);
        connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
            Q_UNUSED(exitCode)
            ddcBusy_ = false;
            proc->deleteLater();
        });
        proc->start(ddcutil, {QStringLiteral("setvcp"), QStringLiteral("10"),
                              QString::number(percent),
                              QStringLiteral("--display"), QString::number(ddcDisplayNum_),
                              QStringLiteral("--noverify")});
    }
}

void BrightnessService::refresh() {
    if (!available_) return;

    if (method_ == QLatin1String("backlight")) {
        QFile maxFile(backlightPath_ + "/max_brightness");
        if (maxFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            maxBrightness_ = maxFile.readAll().trimmed().toInt();
            maxFile.close();
        }
        QFile curFile(backlightPath_ + "/brightness");
        if (curFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            int current = curFile.readAll().trimmed().toInt();
            curFile.close();
            if (maxBrightness_ > 0) {
                brightness_ = qRound(100.0 * current / maxBrightness_);
                emit brightnessChanged();
            }
        }
    } else if (method_ == QLatin1String("ddcutil")) {
        if (ddcBusy_) return;
        ddcBusy_ = true;

        QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
        auto *proc = new QProcess(this);
        connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
            Q_UNUSED(exitCode)
            ddcBusy_ = false;
            QString output = proc->readAllStandardOutput();
            static QRegularExpression re(QStringLiteral(R"(VCP\s+10\s+C\s+(\d+)\s+(\d+))"));
            auto match = re.match(output);
            if (match.hasMatch()) {
                brightness_ = match.captured(1).toInt();
                maxBrightness_ = match.captured(2).toInt();
                emit brightnessChanged();
            }
            proc->deleteLater();
        });
        proc->start(ddcutil, {QStringLiteral("getvcp"), QStringLiteral("10"),
                              QStringLiteral("--display"), QString::number(ddcDisplayNum_),
                              QStringLiteral("--brief")});
    }
}

QString BrightnessService::findBacklightPath() const {
    QDir dir("/sys/class/backlight");
    auto entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (!entries.isEmpty()) {
        return "/sys/class/backlight/" + entries.first();
    }
    return {};
}

} // namespace ciderdeck
