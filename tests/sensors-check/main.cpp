#include <QCoreApplication>
#include <QLibraryInfo>
#include <QSettings>
#include <QSensor>
#include <QTimer>
#include <cstdio>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QSettings conf(QSettings::SystemScope, QStringLiteral("QtProject"), QStringLiteral("Sensors"));
    printf("settings %s: %s, %d keys\n", qPrintable(QLibraryInfo::location(QLibraryInfo::SettingsPath)),
           qPrintable(conf.fileName()), conf.allKeys().size());
    for (const QByteArray &type : QSensor::sensorTypes()) {
        QByteArray ids;
        for (const QByteArray &id : QSensor::sensorsForType(type))
            ids += ' ' + id;
        printf("%s:%s (default %s)\n", type.constData(), ids.constData(),
               QSensor::defaultSensorForType(type).constData());
    }
    const QByteArray types[] = { "QAccelerometer", "QOrientationSensor", "QRotationSensor",
                                 "QAmbientLightSensor", "QProximitySensor", "QMagnetometer", "QCompass" };
    for (const QByteArray &type : types) {
        auto *sensor = new QSensor(type, &app);
        auto *count = new int(0);
        QObject::connect(sensor, &QSensor::readingChanged, [sensor, count] {
            if (++*count > 2)
                return;
            QByteArray values;
            for (int i = 0; i < sensor->reading()->valueCount(); ++i)
                values += ' ' + sensor->reading()->value(i).toByteArray();
            printf("%s %s:%s\n", sensor->type().constData(), sensor->identifier().constData(), values.constData());
            fflush(stdout);
        });
        if (!sensor->start())
            printf("%s: could not start\n", type.constData());
    }
    QTimer::singleShot(3000, &app, &QCoreApplication::quit);
    return app.exec();
}
