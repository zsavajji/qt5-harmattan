#include <QGuiApplication>
#include <QQuickView>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickView view;
    view.setSource(QUrl(QStringLiteral("qrc:/main.qml")));
    view.showFullScreen(); // Harmattan apps own the whole screen and draw the status bar
    return app.exec();
}
