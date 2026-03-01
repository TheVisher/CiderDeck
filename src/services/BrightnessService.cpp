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

    // Add single backlight display entry
    DisplayInfo info;
    info.ddcDisplayNum = 0;
    info.name = QStringLiteral("Built-in Display");
    info.brightness = brightness_;
    info.maxBrightness = maxBrightness_;
    ddcDisplays_.append(info);

    QVariantMap entry;
    entry[QStringLiteral("id")] = 0;
    entry[QStringLiteral("name")] = info.name;
    displays_.append(entry);

    emit availableChanged();
    emit brightnessChanged();
    emit displaysChanged();
}

void BrightnessService::initDdcutil() {
    QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
    if (ddcutil.isEmpty()) return;

    enumerateDdcDisplays();

    if (ddcDisplays_.isEmpty()) return;

    method_ = QStringLiteral("ddcutil");
    available_ = true;

    // Set legacy single-display fields from first display
    ddcDisplayNum_ = ddcDisplays_.first().ddcDisplayNum;
    brightness_ = ddcDisplays_.first().brightness;
    maxBrightness_ = ddcDisplays_.first().maxBrightness;

    qInfo() << "[BrightnessService] Found" << ddcDisplays_.size() << "DDC displays";
    for (const auto &d : ddcDisplays_) {
        qInfo() << "  Display" << d.ddcDisplayNum << d.name
                << "brightness:" << d.brightness << "/" << d.maxBrightness;
    }

    emit availableChanged();
    emit brightnessChanged();
    emit displaysChanged();
}

void BrightnessService::enumerateDdcDisplays() {
    QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
    if (ddcutil.isEmpty()) return;

    // Run ddcutil detect to enumerate all monitors
    QProcess detectProc;
    detectProc.start(ddcutil, {QStringLiteral("detect"), QStringLiteral("--brief")});
    if (!detectProc.waitForFinished(15000)) return;

    QString detectOutput = detectProc.readAllStandardOutput();

    static QRegularExpression displayRe(QStringLiteral(R"(Display\s+(\d+))"));
    static QRegularExpression monitorRe(QStringLiteral(R"(Monitor:\s+(.+))"));

    const auto lines = detectOutput.split(QLatin1Char('\n'));
    int currentDisplayNum = -1;
    QString currentMonitorName;

    for (const QString &line : lines) {
        auto displayMatch = displayRe.match(line);
        if (displayMatch.hasMatch()) {
            // Save previous display if we had one
            if (currentDisplayNum > 0) {
                DisplayInfo info;
                info.ddcDisplayNum = currentDisplayNum;
                info.name = currentMonitorName.isEmpty()
                    ? QStringLiteral("Display %1").arg(currentDisplayNum)
                    : currentMonitorName;
                ddcDisplays_.append(info);

                QVariantMap entry;
                entry[QStringLiteral("id")] = ddcDisplays_.size() - 1;
                entry[QStringLiteral("name")] = info.name;
                displays_.append(entry);
            }
            currentDisplayNum = displayMatch.captured(1).toInt();
            currentMonitorName.clear();
            continue;
        }

        auto monitorMatch = monitorRe.match(line);
        if (monitorMatch.hasMatch() && currentDisplayNum > 0) {
            currentMonitorName = monitorMatch.captured(1).trimmed();
        }
    }

    // Don't forget the last display
    if (currentDisplayNum > 0) {
        DisplayInfo info;
        info.ddcDisplayNum = currentDisplayNum;
        info.name = currentMonitorName.isEmpty()
            ? QStringLiteral("Display %1").arg(currentDisplayNum)
            : currentMonitorName;
        ddcDisplays_.append(info);

        QVariantMap entry;
        entry[QStringLiteral("id")] = ddcDisplays_.size() - 1;
        entry[QStringLiteral("name")] = info.name;
        displays_.append(entry);
    }

    // Now read brightness for each display
    for (int i = 0; i < ddcDisplays_.size(); ++i) {
        QProcess proc;
        proc.start(ddcutil, {QStringLiteral("getvcp"), QStringLiteral("10"),
                             QStringLiteral("--display"), QString::number(ddcDisplays_[i].ddcDisplayNum),
                             QStringLiteral("--brief")});
        if (!proc.waitForFinished(5000)) continue;

        QString output = proc.readAllStandardOutput();
        static QRegularExpression re(QStringLiteral(R"(VCP\s+10\s+C\s+(\d+)\s+(\d+))"));
        auto match = re.match(output);
        if (match.hasMatch()) {
            ddcDisplays_[i].brightness = match.captured(1).toInt();
            ddcDisplays_[i].maxBrightness = match.captured(2).toInt();
        }
    }
}

int BrightnessService::getBrightness(int displayIndex) const {
    if (displayIndex < 0 || displayIndex >= ddcDisplays_.size())
        return brightness_;
    return ddcDisplays_[displayIndex].brightness;
}

void BrightnessService::setBrightness(int percent) {
    setBrightness(0, percent);
}

void BrightnessService::setBrightness(int displayIndex, int percent) {
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
            if (displayIndex >= 0 && displayIndex < ddcDisplays_.size()) {
                ddcDisplays_[displayIndex].brightness = percent;
            }
            emit brightnessChanged();
            emit displayBrightnessChanged(displayIndex, percent);
        }
    } else if (method_ == QLatin1String("ddcutil")) {
        if (displayIndex < 0 || displayIndex >= ddcDisplays_.size()) return;
        auto &disp = ddcDisplays_[displayIndex];
        if (disp.busy) return;
        disp.busy = true;
        disp.brightness = percent;

        // Update legacy field if this is the first display
        if (displayIndex == 0) {
            brightness_ = percent;
            emit brightnessChanged();
        }
        emit displayBrightnessChanged(displayIndex, percent);

        QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));
        auto *proc = new QProcess(this);
        connect(proc, &QProcess::finished, this, [this, displayIndex, proc](int exitCode, QProcess::ExitStatus) {
            Q_UNUSED(exitCode)
            if (displayIndex >= 0 && displayIndex < ddcDisplays_.size()) {
                ddcDisplays_[displayIndex].busy = false;
            }
            proc->deleteLater();
        });
        proc->start(ddcutil, {QStringLiteral("setvcp"), QStringLiteral("10"),
                              QString::number(percent),
                              QStringLiteral("--display"), QString::number(disp.ddcDisplayNum),
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
        QString ddcutil = QStandardPaths::findExecutable(QStringLiteral("ddcutil"));

        for (int i = 0; i < ddcDisplays_.size(); ++i) {
            if (ddcDisplays_[i].busy) continue;
            ddcDisplays_[i].busy = true;

            auto *proc = new QProcess(this);
            connect(proc, &QProcess::finished, this, [this, i, proc](int exitCode, QProcess::ExitStatus) {
                Q_UNUSED(exitCode)
                if (i >= ddcDisplays_.size()) { proc->deleteLater(); return; }
                ddcDisplays_[i].busy = false;
                QString output = proc->readAllStandardOutput();
                static QRegularExpression re(QStringLiteral(R"(VCP\s+10\s+C\s+(\d+)\s+(\d+))"));
                auto match = re.match(output);
                if (match.hasMatch()) {
                    ddcDisplays_[i].brightness = match.captured(1).toInt();
                    ddcDisplays_[i].maxBrightness = match.captured(2).toInt();
                    emit displayBrightnessChanged(i, ddcDisplays_[i].brightness);
                    if (i == 0) {
                        brightness_ = ddcDisplays_[i].brightness;
                        maxBrightness_ = ddcDisplays_[i].maxBrightness;
                        emit brightnessChanged();
                    }
                }
                proc->deleteLater();
            });
            proc->start(ddcutil, {QStringLiteral("getvcp"), QStringLiteral("10"),
                                  QStringLiteral("--display"), QString::number(ddcDisplays_[i].ddcDisplayNum),
                                  QStringLiteral("--brief")});
        }
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
