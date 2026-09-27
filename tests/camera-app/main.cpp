#include <QGuiApplication>
#include <QQuickView>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickView view;
    // A QML file as the first argument replaces the built-in page (to try changes over ssh).
    view.setSource(argc > 1 ? QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]))
                            : QUrl(QStringLiteral("qrc:/main.qml")));
    view.showFullScreen();
    return app.exec();
}
