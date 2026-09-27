// 2.2 check on the phone: QtCore and QtNetwork load with our libstdc++, C++11 <cmath>
// works, and QTcpServer / QLocalServer accept connections although accept4() is ENOSYS
// there (Qt is configured with -no-feature-threadsafe-cloexec).
#include <QCoreApplication>
#include <QFile>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTcpServer>
#include <QTcpSocket>
#include <cmath>
#include <cstdio>

static int fail(const char *what, const QString &why)
{
    std::printf("FAIL: %s: %s\n", what, qPrintable(why));
    return 1;
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    std::printf("Qt %s, std::hypot(3, 4) = %g\n", qVersion(), std::hypot(3.0, 4.0));

    QTcpServer tcp;
    if (!tcp.listen(QHostAddress::LocalHost))
        return fail("tcp listen", tcp.errorString());
    QTcpSocket tcpClient;
    tcpClient.connectToHost(QHostAddress::LocalHost, tcp.serverPort());
    if (!tcp.waitForNewConnection(3000) || !tcp.nextPendingConnection())
        return fail("tcp accept", tcp.errorString());
    std::puts("QTcpServer accept: ok");

    const QString name = QStringLiteral("qt5-harmattan-check");
    QLocalServer::removeServer(name);
    QLocalServer local;
    if (!local.listen(name))
        return fail("local listen", local.errorString());
    QLocalSocket localClient;
    localClient.connectToServer(name);
    if (!local.waitForNewConnection(3000) || !local.nextPendingConnection())
        return fail("local accept", local.errorString());
    std::puts("QLocalServer accept: ok");

    QFile maps(QStringLiteral("/proc/self/maps"));
    maps.open(QIODevice::ReadOnly);
    for (const QByteArray &line : maps.readAll().split('\n'))
        if ((line.contains("libstdc++") || line.contains("libgcc_s")) && line.contains("r-xp"))
            std::puts(line.mid(line.indexOf('/')).constData());
    std::puts("OK");
    return 0;
}
