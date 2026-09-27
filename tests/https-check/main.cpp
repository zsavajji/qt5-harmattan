#include <QCoreApplication>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSslCipher>
#include <QSslSocket>
#include <cstdio>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    printf("built with %s, running %s\n", qPrintable(QSslSocket::sslLibraryBuildVersionString()),
           qPrintable(QSslSocket::sslLibraryVersionString()));
    QNetworkAccessManager nam;
    const QStringList urls = app.arguments().mid(1);
    int pending = urls.size();
    for (const QString &url : urls) {
        QNetworkReply *reply = nam.get(QNetworkRequest(QUrl(url)));
        QObject::connect(reply, &QNetworkReply::finished, [&, reply, url] {
            const QSslConfiguration ssl = reply->sslConfiguration();
            printf("%s: HTTP %d, %s, %s: %s\n", qPrintable(url),
                   reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(),
                   qPrintable(ssl.sessionCipher().protocolString()), qPrintable(ssl.sessionCipher().name()),
                   reply->error() == QNetworkReply::NoError ? "ok" : qPrintable(reply->errorString()));
            if (--pending == 0)
                app.quit();
        });
    }
    return pending ? app.exec() : 0;
}
