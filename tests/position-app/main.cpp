#include <QGeoSatelliteInfoSource>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickView view;
    // Satellites have no QML type in Qt 5.15: counted here, shown by the page.
    QQmlContext *context = view.rootContext();
    context->setContextProperty("satellites", QStringLiteral("no satellite source"));
    if (QGeoSatelliteInfoSource *s = QGeoSatelliteInfoSource::createDefaultSource(&app)) {
        auto show = [context](const char *what, int n) {
            qInfo("satellites %s: %d", what, n);
            context->setContextProperty("satellites", QStringLiteral("satellites %1: %2").arg(what).arg(n));
        };
        QObject::connect(s, &QGeoSatelliteInfoSource::satellitesInViewUpdated,
                         [show](const QList<QGeoSatelliteInfo> &l) { show("in view", l.size()); });
        QObject::connect(s, &QGeoSatelliteInfoSource::satellitesInUseUpdated,
                         [show](const QList<QGeoSatelliteInfo> &l) { show("in use", l.size()); });
        QObject::connect(s, QOverload<QGeoSatelliteInfoSource::Error>::of(&QGeoSatelliteInfoSource::error),
                         [](QGeoSatelliteInfoSource::Error e) { qInfo("satellite error %d", e); });
        s->startUpdates();
    }
    // A QML file as the first argument replaces the built-in page (to try changes over ssh).
    view.setSource(argc > 1 ? QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]))
                            : QUrl(QStringLiteral("qrc:/main.qml")));
    view.showFullScreen();
    return app.exec();
}
