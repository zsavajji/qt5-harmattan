// 2.3 go/no-go test app: GPU renderer, frame rate, taps and text input on the phone.
// Everything the checks need also goes to stdout, because we run it over SSH (and
// invoker would discard stderr anyway).
#include <QAbstractNativeEventFilter>
#include <QAtomicInt>
#include <QGuiApplication>
#include <QOpenGLContext>
#include <qpa/qplatformnativeinterface.h>
#include <QOpenGLFunctions>
#include <QQmlContext>
#include <QQuickView>
#include <QScreen>
#include <QTimer>
#include <cstdio>
#include <xcb/xcb.h>

// Logs every X client message with its type and first data atom, by name (3.2).
class ClientMessageTrace : public QAbstractNativeEventFilter
{
public:
    bool nativeEventFilter(const QByteArray &type, void *message, long *) override
    {
        auto *ev = static_cast<xcb_generic_event_t *>(message);
        if (type != "xcb_generic_event_t" || (ev->response_type & 0x7f) != XCB_CLIENT_MESSAGE)
            return false;
        auto *cm = reinterpret_cast<xcb_client_message_event_t *>(ev);
        std::printf("client message %s [%s]\n", name(cm->type).constData(), name(cm->data.data32[0]).constData());
        std::fflush(stdout);
        return false;
    }

private:
    static QByteArray name(xcb_atom_t atom)
    {
        auto *c = static_cast<xcb_connection_t *>(
            QGuiApplication::platformNativeInterface()->nativeResourceForIntegration("connection"));
        xcb_get_atom_name_reply_t *r = xcb_get_atom_name_reply(c, xcb_get_atom_name(c, atom), nullptr);
        if (!r)
            return QByteArray::number(atom);
        QByteArray n(xcb_get_atom_name_name(r), xcb_get_atom_name_name_length(r));
        free(r);
        return n;
    }
};

// Logs what the window manager does to the window (3.2: swipe and switcher behaviour).
class WindowTrace : public QObject
{
public:
    explicit WindowTrace(QWindow *window) : QObject(window)
    {
        window->installEventFilter(this);
        connect(window, &QWindow::windowStateChanged, this, [](Qt::WindowState state) {
            std::printf("window state %d\n", int(state));
            std::fflush(stdout);
        });
        connect(window, &QWindow::visibilityChanged, this, [](QWindow::Visibility v) {
            std::printf("visibility %d\n", int(v));
            std::fflush(stdout);
        });
        connect(qApp, &QCoreApplication::aboutToQuit, this, [] { std::puts("aboutToQuit"); std::fflush(stdout); });
    }

protected:
    bool eventFilter(QObject *, QEvent *e) override
    {
        if (e->type() == QEvent::Close || e->type() == QEvent::Hide || e->type() == QEvent::Show
            || e->type() == QEvent::Expose || e->type() == QEvent::FocusIn || e->type() == QEvent::FocusOut) {
            std::printf("event %d\n", int(e->type()));
            std::fflush(stdout);
        }
        return false;
    }
};

class Stats : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString renderer MEMBER m_renderer NOTIFY rendererChanged)
    Q_PROPERTY(int fps MEMBER m_fps NOTIFY fpsChanged)

public:
    explicit Stats(QQuickWindow *window)
    {
        // Both signals come from the render thread when the threaded render loop is used.
        connect(window, &QQuickWindow::sceneGraphInitialized, this, [this, window] {
            // No context means Qt Quick fell back to its software renderer.
            QOpenGLContext *context = window->openglContext();
            const QString renderer = context
                ? QString::fromLatin1(reinterpret_cast<const char *>(context->functions()->glGetString(GL_RENDERER)))
                : QStringLiteral("software (no OpenGL)");
            QMetaObject::invokeMethod(this, [this, renderer] {
                m_renderer = renderer;
                emit rendererChanged();
                std::printf("GL_RENDERER %s\n", qPrintable(renderer));
                std::fflush(stdout);
            });
        }, Qt::DirectConnection);
        connect(window, &QQuickWindow::frameSwapped, this, [this] { m_frames.fetchAndAddRelaxed(1); },
                Qt::DirectConnection);

        auto *timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, [this] {
            m_fps = m_frames.fetchAndStoreRelaxed(0);
            emit fpsChanged();
            std::printf("fps %d\n", m_fps);
            std::fflush(stdout);
        });
        timer->start(1000);
    }

    Q_INVOKABLE void log(const QString &line)
    {
        std::printf("%s\n", qPrintable(line));
        std::fflush(stdout);
    }

signals:
    void rendererChanged();
    void fpsChanged();

private:
    QString m_renderer = QStringLiteral("(not yet)");
    int m_fps = 0;
    QAtomicInt m_frames;
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    ClientMessageTrace clientMessages;
    app.installNativeEventFilter(&clientMessages);
    QQuickView view;
    // No decorations, like MeeGo apps: mcompositor then doesn't composite the fullscreen window.
    view.setFlags(view.flags() | Qt::FramelessWindowHint);
    // Follow the device (3.2): main.qml rotates the content, and the window reports it, so
    // mcompositor reads swipes the right way round.
    QObject::connect(view.screen(), &QScreen::orientationChanged, &view, [&view](Qt::ScreenOrientation o) {
        view.reportContentOrientationChange(o);
        std::printf("orientation %d\n", int(o));
        std::fflush(stdout);
    });
    Stats stats(&view);
    new WindowTrace(&view);
    view.rootContext()->setContextProperty(QStringLiteral("stats"), &stats);
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setSource(QUrl(QStringLiteral("qrc:/main.qml")));
    view.showFullScreen();
    return app.exec();
}

#include "main.moc"
