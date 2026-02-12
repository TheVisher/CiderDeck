#pragma once

#include <QObject>

namespace ciderdeck {

class CommandRunner : public QObject {
    Q_OBJECT

public:
    explicit CommandRunner(QObject *parent = nullptr);

    Q_INVOKABLE void run(const QString &command);

signals:
    void finished(int exitCode, const QString &stdout_, const QString &stderr_);

private:
};

} // namespace ciderdeck
