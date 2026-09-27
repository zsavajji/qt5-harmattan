# The sample app with CMake (cmake/harmattan-qt5.cmake); sample-app.pro is the qmake build
# that scripts/package.sh uses. Both compile the QML in.
cmake_minimum_required(VERSION 3.16)
project(qt5-sample LANGUAGES CXX)

find_package(Qt5 5.15 REQUIRED COMPONENTS Quick QuickCompiler)
qtquick_compiler_add_resources(QML_RESOURCES qml.qrc)

add_executable(qt5-sample main.cpp ${QML_RESOURCES})
target_link_libraries(qt5-sample PRIVATE Qt5::Quick)
install(TARGETS qt5-sample DESTINATION /opt/qt5-sample/bin)
