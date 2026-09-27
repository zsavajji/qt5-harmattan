// Runs a QML file with the phone's own Qt 4 and com.nokia.meego 1.0, for side-by-side
// checks against the Qt 5 port (3.3): qml4view page.qml
// Build with MADDE's GCC 4.4 and its Harmattan specs (hard float), on the box:
//   M=$QT_SDK_PATH/Madde S=$MADDE_SYSROOT I=$S/usr/include/qt4
//   $M/toolchains/arm-2009q3-67-*/arm-2009q3-67/bin/arm-none-linux-gnueabi-g++ \
//     -specs=$M/targets/harmattan_10.2011.34-1_rt1.2/specs --sysroot=$S -O2 qml4view.cpp \
//     -I$I -I$I/QtCore -I$I/QtGui -I$I/QtDeclarative -lQtDeclarative -lQtGui -lQtCore -o qml4view
#include <QApplication>
#include <QDeclarativeView>
#include <QUrl>

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QDeclarativeView view;
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    view.showFullScreen();
    return app.exec();
}
