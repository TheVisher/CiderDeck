#include "CommandRunner.h"

#include <QProcess>

namespace ciderdeck {

CommandRunner::CommandRunner(QObject *parent)
    : QObject(parent) {}

void CommandRunner::run(const QString &command) {
    auto *process = new QProcess(this);

    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, [this, process](int exitCode, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        const QString err = QString::fromUtf8(process->readAllStandardError());
        emit finished(exitCode, out, err);
        process->deleteLater();
    });

    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError) {
        emit finished(-1, QString(), process->errorString());
        process->deleteLater();
    });

    process->start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
}

} // namespace ciderdeck
