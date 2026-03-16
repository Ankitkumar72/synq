# Synq

Synq is a powerful and intuitive task and note management application built with Flutter. It seamlessly merges task tracking, note-taking, and daily schedule planning into an elegant, unified interface.

## 🚀 Features

- **Advanced Task & Event Management**
  - Create, edit, and organize tasks and calendar events.
  - Universal **Schedule Planner** dialog to easily set specific times, durations, and all-day indicators.
  - Deep support for **Recurring Tasks & Events** (Daily, Weekly, Monthly, Yearly repeats).
  - Configurable push notification reminders.

- **Note Taking**
  - Rich text note-taking experience with sub-tasks and detailed body descriptions.
  - Organize notes and tasks into hierarchical folders and tags for easy discovery.
  - Seamless, swift navigation between specific notes and folder structures.

- **Visual Timeline & Planning**
  - **Live Daily Timeline**: A dynamic, visual representation of today's schedule, featuring a real-time current minute indicator tracking alongside your hour blocks.
  - Interactive "now" positioning automatically scrolls to the current hour.
  - **Weekly & Monthly Views**: Comprehensive calendar selectors to zoom out on your schedule.

- **Deep Focus Mode**
  - Dedicated **Focus Timer** with fluid waveforms and circular countdown animations.
  - Support for scheduled countdown blocks and open-ended generic focus sessions (elapsed time tracking).
  - Ability to quickly start focus sessions directly from scheduled tasks.

- **Authentication & Security**
  - Secure Email & Password Login/Signup.
  - **Google Sign-In** integration for minimal friction.
  - Robust automatic user session management.

- **Profile & Subscription**
  - **User Profile**: Manage account settings, offline data, and view productivity stats.
  - **Subscription Plans**: Clean "Free vs Pro" subscription page with clear feature tiering and payment hooks.
  - **Secure Data**: Data is stored locally and synced securely over TLS.

- **Polished UI/UX**
  - **Dynamic Next Up Dashboard**: Intelligently surfaces your immediate upcoming tasks, or provides a daily summary if you're caught up.
  - **Premium Design**: Carefully crafted typography (Google Fonts), soft drop shadows, custom themes (Light & Dark), and rounded bento-box layouts.
  - **Fluid Navigation**: Persistent, state-restoring bottom navigation shell.
  - **Animations**: Subtle micro-interactions and transitions across sheets, modals, and list items.

## ✨ Recent Engine Updates

- **Robust Real-Time Sync**: Rewrote the synchronization layer using a strong `FirebaseSyncCoordinator` to ensure reliable offline-first data availability and instantaneous updates across devices.
- **Independent Categories**: Separated state management for task and note categories to allow more modular and strict organization boundaries. 

## 🏗 Architecture

Synq is built using a **Feature-First Architecture** combined with **Riverpod** for state management and **Firebase** for the backend.

### Project Structure


```
lib/
├── core/                   # Shared resources
│   ├── services/           # External services (Firebase, Notifications)
│   ├── theme/              # App theme definitions (Colors, TextStyles)
│   ├── utils/              # Helper functions and constants
│   ├── navigation/         # Navigation helpers
│   └── providers/          # Global providers (e.g. Firebase error)
│
├── features/               # Feature modules
│   ├── auth/               # Authentication logic & UI
│   ├── home/               # Home screen dashboard
│   ├── notes/              # Note taking & management
│   ├── timeline/           # Daily, Weekly, Monthly timeline & schedule views
│   ├── shell/              # Main app shell (Bottom Nav)
│   ├── focus/              # Focus mode active timers & metrics
│   └── profile/            # User profile & Subscription management
│
└── main.dart               # Entry point & App initialization
```

### Key Technologies

*   **State Management**: [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod)
    *   Used for dependency injection and robust state management across the app.
    *   Leverages `StateNotifierProvider`, `StreamProvider`, and `Provider` for reactive UI updates without deep widget trees.
*   **Backend**: [Firebase](https://firebase.google.com/)
    *   **Authentication**: Manages user identity and sign-in.
    *   **Cloud Firestore**: Real-time NoSQL database for synchronizing tasks, notes, folder hierarchies, and user data.
    *   **Storage**: For storing user profile assets and file attachments.
*   **Local Storage**: [Hive](https://pub.dev/packages/hive)
    *   Employed for local caching, persistent queues, and instant launch preferences.
*   **Navigation**:
    *   Standard `Navigator` 2.0 concepts wrapped in a persistent shell-base structure.
    *   `IndexedStack` inside `MainShell` effortlessly maintains the parallel state of each top-level tab.

### Data Flow

1.  **Repository Pattern**: Each feature has a `data` layer (e.g., `FirestoreNotesRepository`) that handles direct communication with APIs/Firebase.
2.  **Providers/Notifiers**: The `presentation` layer interacts with data exclusively through Riverpod providers (e.g., `NotesNotifier`), heavily abstracting and isolating the business logic.
3.  **UI**: Widgets consume these providers using `ConsumerWidget` to rebuild efficiently and reactively when specific states drastically change.

## 🛠 Getting Started

### Prerequisites

- Flutter SDK (version ^3.10.7 or higher)
- Dart SDK
- Firebase Project setup

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Ankitkumar72/synq.git
    cd synq
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    *   This project relies on `firebase_options.dart`. Ensure you have configured your Firebase project using the FlutterFire CLI.
    *   Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective platform directories if manual setup is required (the CLI usually handles this entirely).

4.  **Run the App**:
    ```bash
    flutter run
    ```

## 📦 Dependencies

Key packages used in this project:

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | Core State Management & Injection |
| `firebase_core/auth/cloud_firestore` | Scalable Backend Integration |
| `google_sign_in` | Google Authentication Portal |
| `hive` / `hive_flutter` | Lightweight Fast Local Database |
| `intl` | Robust Date/Time Formatting & Parsing |
| `uuid` | Unique ID generation for local objects |
| `google_fonts` | Advanced Typography handling |
| `flutter_local_notifications` | Native OS Local Reminders |

## 🤝 Contributing

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request