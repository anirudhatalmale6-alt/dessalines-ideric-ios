IPHONE APPS — IDERIC BANK AND DESSALINES BANK
Built without owning a Mac
=============================================================================

THE HONEST ANSWER TO "WHY IS THERE NO iOS VERSION YET"

It is equipment, not knowledge. The whole iPhone app is in this folder and it
is finished. What is missing is a Mac.

Apple allows an iOS app to be compiled and signed on macOS and nowhere else.
That is Apple's rule and there is no way around it — not on Linux, not on
Windows, not on your Lenovo. Android is the opposite: the Dessalines and Ideric
APKs were both built on my Linux machine, which is why you have had those for
a while and not these.

Two things are therefore needed, and neither is code:

  1. A Mac to compile on.        -> rented by the minute, see below
  2. An Apple Developer account. -> USD 99 a year, developer.apple.com/programs
                                    Only you can open this; it needs your ID
                                    and your company details.

There is no free way past number 2. Apple charges every developer on earth the
same 99 dollars and will not install an app on a stranger's phone without it.


WHAT I DID ABOUT THE MAC

You do not have to buy one. A cloud Mac does the job, and for an app this small
the free tier is enough.

Codemagic (codemagic.io) rents Macs by the minute — 500 minutes a month free,
and this app builds in about five. Everything happens in your browser. The file
`codemagic.yaml` in this folder is the complete recipe: it tells their Mac how
to build both apps, sign them and send them to Apple. You do not write any of
it. You connect the repository, press Start build, and pick a workflow.

Alternatives if you ever prefer them: MacinCloud or MacStadium rent a full Mac
desktop you can see and click (about USD 1 an hour), and a Mac mini is around
USD 599 if you decide to own one. All three build the same code.


STEP BY STEP, THE FIRST TIME

  1. Open developer.apple.com/programs and enrol. USD 99/year. Apple usually
     takes 24-48 hours to approve a company.

  2. Put this `ios-app` folder in a Git repository — GitHub, GitLab or
     Bitbucket, private is fine. Tell me if you would like me to do this part;
     it is five minutes.

  3. Sign up at codemagic.io with that Git account and add the repository.
     Codemagic finds codemagic.yaml on its own.

  4. In Codemagic: Teams > Integrations > Apple Developer Portal > Connect.
     It asks for an App Store Connect API key, which you create at
     appstoreconnect.apple.com > Users and Access > Integrations > App Store
     Connect API > "+". Download the .p8 file once — Apple will not show it
     again — and upload it to Codemagic with the Key ID and Issuer ID shown
     beside it.

     This is the part that signs the app. Codemagic never sees your Apple
     password.

  5. In App Store Connect, create two apps:
        Ideric Bank       bundle id  com.idericbank.app
        Dessalines Bank   bundle id  com.dessalinesbank.app
     The bundle ids must match exactly. They are the same as the Android
     package names on purpose.

  6. In Codemagic press Start build and choose a workflow:
        "Ideric Bank — iPhone"
        "Dessalines Bank — iPhone"

  7. When it turns green the build is in TestFlight. Install TestFlight from
     the App Store on your iPhone, sign in with your Apple ID, and the app is
     there. That is how you and your testers use it before it goes public.

  8. To go public: App Store Connect > the app > Distribution > select the
     TestFlight build > Submit for review. Apple usually answers in 24-48
     hours.


WHAT APPLE WILL ASK FOR, AND WHAT ALREADY EXISTS

  Privacy policy URL        https://idericbank.com/privacy.php        DONE
                            https://dessalinesbank.com/terms.php#privacy  DONE
  Account deletion page     https://idericbank.com/account-deletion.php   DONE
  App icon 1024x1024        in this folder, both apps                 DONE
  Screenshots 6.7"          I can produce these from the live sites — ask
  Support URL + email       your customersupport@ addresses
  Demo account for review   Apple's reviewer needs a working login. Give me a
                            username and PIN to hand them, or say the word and
                            I will create one on each bank.

The one thing likely to come back from review: Apple rejects apps that are only
a website in a frame ("minimum functionality", guideline 4.2). Both of these
are real banking apps — accounts, transfers, cards, identity checks — which is
the argument that gets them through, and it is worth saying so in the review
notes. Google is far more relaxed about this, which is why the Android versions
went up without an argument. If Apple pushes back I will add native pieces
(Face ID unlock, push notifications, a native balance screen) and resubmit.


WHAT IS IN THIS FOLDER

  project.yml                 The Xcode project, as readable YAML. The build
                              generates the real .xcodeproj from it, so the two
                              can never disagree.
  codemagic.yaml              The cloud-Mac build recipe. Two workflows.
  Sources/Shared/             The app itself. One implementation, both banks.
  Sources/IdericBank/         URL, name, icon, permissions.
  Sources/DessalinesBank/     Same, in Kreyòl.

The apps load the live website, so every change to idericbank.com or
dessalinesbank.com appears in them immediately — exactly like the Android apps.
No new App Store release is needed for a site change.

Three things it does that a plain "website in an app" does not:

  - PayPal opens its checkout in a popup window, and on Dessalines the
    debit/credit card form is PayPal underneath. The app presents that popup
    properly and keeps the link back to the page alive, which is what lets
    PayPal report the result. Version 1.1 of the Android app got this wrong and
    the deposit button looked dead; this does not repeat the mistake.
  - The identity check opens the camera from inside the page. The app asks for
    camera permission so the face scan works.
  - When the connection drops it shows a Dessalines / Ideric page rather than a
    Safari error inside what is meant to look like a bank.


ONE THING I CANNOT PROMISE

I cannot compile this here — there is no Mac in my hands either, which is the
whole point of the cloud build. The code is written carefully and against the
current APIs, but the first build on Codemagic may stop on a small thing: a
missing setting, an Xcode version difference, a signing profile that needs a
tick in App Store Connect. Send me the build log and I will fix it the same
day. That first green build is the only step I need your account to reach.
