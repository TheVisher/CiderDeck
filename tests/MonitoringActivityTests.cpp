#include <QObject>
#include <QTest>
#include <QTimer>

#include "services/ProcessManagerService.h"
#include "services/SystemMonitorService.h"

using namespace ciderdeck;

namespace {

class TestSystemMonitorService : public SystemMonitorService {
public:
    using SystemMonitorService::SystemMonitorService;

    int refreshCount = 0;

protected:
    void poll() override { ++refreshCount; }
};

class TestProcessManagerService : public ProcessManagerService {
public:
    using ProcessManagerService::ProcessManagerService;

    int refreshCount = 0;

protected:
    void poll() override { ++refreshCount; }
};

template<typename Service>
void verifyConsumerLifecycle(Service &service, int expectedInterval)
{
    const auto timers = service.template findChildren<QTimer *>(
        QString(), Qt::FindDirectChildrenOnly);
    QCOMPARE(timers.size(), 1);
    QTimer *timer = timers.constFirst();
    QCOMPARE(timer->interval(), expectedInterval);
    QVERIFY(!timer->isActive());
    QCOMPARE(service.refreshCount, 0);

    QObject firstConsumer;
    QObject secondConsumer;

    service.setConsumerActive(&firstConsumer, true);
    QCOMPARE(service.refreshCount, 1);
    QVERIFY(timer->isActive());

    service.setConsumerActive(&firstConsumer, true);
    service.setConsumerActive(&secondConsumer, true);
    QCOMPARE(service.refreshCount, 1);
    QVERIFY(timer->isActive());

    service.setConsumerActive(&firstConsumer, false);
    service.setConsumerActive(&firstConsumer, false);
    QVERIFY(timer->isActive());

    service.setConsumerActive(&secondConsumer, false);
    service.setConsumerActive(&secondConsumer, false);
    QVERIFY(!timer->isActive());

    service.setConsumerActive(&firstConsumer, true);
    QCOMPARE(service.refreshCount, 2);
    QVERIFY(timer->isActive());
    service.setConsumerActive(&firstConsumer, false);
    QVERIFY(!timer->isActive());

    auto *destroyedConsumer = new QObject;
    service.setConsumerActive(destroyedConsumer, true);
    QCOMPARE(service.refreshCount, 3);
    QVERIFY(timer->isActive());
    delete destroyedConsumer;
    QVERIFY(!timer->isActive());

    service.setConsumerActive(nullptr, true);
    QCOMPARE(service.refreshCount, 3);
    QVERIFY(!timer->isActive());
}

} // namespace

class MonitoringActivityTests : public QObject {
    Q_OBJECT

private slots:
    void systemMonitorUsesActiveConsumerLifecycle();
    void processManagerUsesActiveConsumerLifecycle();
};

void MonitoringActivityTests::systemMonitorUsesActiveConsumerLifecycle()
{
    TestSystemMonitorService service;
    verifyConsumerLifecycle(service, 2000);
}

void MonitoringActivityTests::processManagerUsesActiveConsumerLifecycle()
{
    TestProcessManagerService service;
    verifyConsumerLifecycle(service, 3000);
}

QTEST_GUILESS_MAIN(MonitoringActivityTests)

#include "MonitoringActivityTests.moc"
