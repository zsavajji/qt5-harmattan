#include <QContactDetailFilter>
#include <QContactDisplayLabel>
#include <QContactEmailAddress>
#include <QContactManager>
#include <QContactPhoneNumber>
#include <QCoreApplication>
#include <cstdio>

QTCONTACTS_USE_NAMESPACE

// The default manager and what it reads from the phone's address book: every contact's label,
// numbers (context, subtypes) and addresses, then a filtered, sorted fetch. Exit status 1 when
// the default is not the Tracker engine or a fetch fails; run it from ssh, then without the
// TrackerReadAccess credential the error is PermissionsError (9) on a closed-mode phone.
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QContactManager manager;
    printf("managers %s, default %s\n", qPrintable(QContactManager::availableManagers().join(QLatin1Char(' '))),
           qPrintable(manager.managerName()));

    const QList<QContact> all = manager.contacts();
    printf("%d contacts, error %d\n", all.size(), manager.error());
    for (const QContact &c : all) {
        printf("%s \"%s\"\n", c.id().localId().constData(), qPrintable(c.detail<QContactDisplayLabel>().label()));
        for (const QContactPhoneNumber &p : c.details<QContactPhoneNumber>()) {
            QStringList subTypes;
            for (int s : p.subTypes())
                subTypes << QString::number(s);
            printf("  phone %s context %d subtypes %s\n", qPrintable(p.number()), p.contexts().value(0, -1),
                   qPrintable(subTypes.join(QLatin1Char(','))));
        }
        for (const QContactEmailAddress &e : c.details<QContactEmailAddress>())
            printf("  email %s context %d\n", qPrintable(e.emailAddress()), e.contexts().value(0, -1));
    }

    // Contacts with a number, by label: the in-memory filter and sort.
    QContactDetailFilter withNumber;
    withNumber.setDetailType(QContactPhoneNumber::Type);
    QContactSortOrder byLabel;
    byLabel.setDetailType(QContactDisplayLabel::Type, QContactDisplayLabel::FieldLabel);
    const QList<QContact> numbered = manager.contacts(withNumber, QList<QContactSortOrder>() << byLabel);
    printf("%d with a phone number, error %d\n", numbered.size(), manager.error());

    const bool ok = manager.managerName() == QLatin1String("tracker") && manager.error() == QContactManager::NoError;
    printf("%s\n", ok ? "ok" : "FAILED");
    return ok ? 0 : 1;
}
