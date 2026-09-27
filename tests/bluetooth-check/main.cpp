#include <QBluetoothDeviceDiscoveryAgent>
#include <QBluetoothLocalDevice>
#include <QBluetoothServiceDiscoveryAgent>
#include <QCoreApplication>
#include <QTimer>
#include <cstdio>

// The local adapter; powered on if it was off (and off again at the end); the devices around
// (for 30 s at most), then the services of the first one found.
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QBluetoothLocalDevice local;
    const bool wasOff = local.hostMode() == QBluetoothLocalDevice::HostPoweredOff;
    printf("local %s %s valid %d host mode %d\n", qPrintable(local.name()),
           qPrintable(local.address().toString()), local.isValid(), local.hostMode());
    auto finish = [&] {
        if (wasOff)
            local.setHostMode(QBluetoothLocalDevice::HostPoweredOff);
        QTimer::singleShot(1000, &app, &QCoreApplication::quit);
    };
    QTimer::singleShot(120000, &app, [&] { printf("timeout\n"); finish(); });

    QBluetoothDeviceDiscoveryAgent devices;
    QBluetoothServiceDiscoveryAgent services;
    QObject::connect(&devices, &QBluetoothDeviceDiscoveryAgent::deviceDiscovered, [](const QBluetoothDeviceInfo &d) {
        printf("device %s \"%s\" rssi %d major class %d\n", qPrintable(d.address().toString()),
               qPrintable(d.name()), d.rssi(), d.majorDeviceClass());
    });
    QObject::connect(&devices, QOverload<QBluetoothDeviceDiscoveryAgent::Error>::of(&QBluetoothDeviceDiscoveryAgent::error),
                     [&] { printf("device discovery error: %s\n", qPrintable(devices.errorString())); finish(); });
    auto devicesDone = [&] {
        const QList<QBluetoothDeviceInfo> found = devices.discoveredDevices();
        printf("%d devices\n", found.size());
        if (found.isEmpty())
            return finish();
        services.setRemoteAddress(found.first().address());
        services.start(QBluetoothServiceDiscoveryAgent::FullDiscovery);
    };
    QObject::connect(&devices, &QBluetoothDeviceDiscoveryAgent::finished, devicesDone);
    QObject::connect(&devices, &QBluetoothDeviceDiscoveryAgent::canceled, devicesDone);
    QObject::connect(&services, &QBluetoothServiceDiscoveryAgent::serviceDiscovered, [](const QBluetoothServiceInfo &s) {
        printf("service \"%s\" %s protocol %d channel %d psm %d\n", qPrintable(s.serviceName()),
               qPrintable(s.serviceUuid().toString()), s.socketProtocol(), s.serverChannel(), s.protocolServiceMultiplexer());
    });
    QObject::connect(&services, QOverload<QBluetoothServiceDiscoveryAgent::Error>::of(&QBluetoothServiceDiscoveryAgent::error),
                     [&] { printf("service discovery error: %s\n", qPrintable(services.errorString())); finish(); });
    QObject::connect(&services, &QBluetoothServiceDiscoveryAgent::finished, [&] {
        printf("%d services\n", services.discoveredServices().size());
        finish();
    });

    auto startDevices = [&] {
        printf("discovering\n");
        devices.start(QBluetoothDeviceDiscoveryAgent::ClassicMethod);
        QTimer::singleShot(30000, &devices, &QBluetoothDeviceDiscoveryAgent::stop);
    };
    QObject::connect(&local, &QBluetoothLocalDevice::hostModeStateChanged, [&](QBluetoothLocalDevice::HostMode mode) {
        printf("host mode %d\n", mode);
        static bool started = false;
        if (mode != QBluetoothLocalDevice::HostPoweredOff && !started) {
            started = true;
            startDevices();
        }
    });
    if (wasOff)
        local.powerOn();
    else
        startDevices();
    return app.exec();
}
