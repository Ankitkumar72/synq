# Synq

Synq is a powerful and intuitive task and note management application built with Flutter. It helps users organize their lives through a clean interface that combines task tracking, note-taking, and daily planning capabilities.

## 🚀 Features

- **Authentication**
  - Secure Email & Password Login/Signup.
  - **Google Sign-In** integration for quick access.
  - Automatic user session management.

- **Task Management**
  - Create, edit, and delete tasks.
  - Organize tasks by categories.
  - Set due dates and reminders.
  - Recursion/Recurring tasks support.

- **Note Taking**
  - Rich text note-taking experience.
  - Organize notes into folders.
  - Seamless navigation between notes and folders.
  - Markdown-style editing capabilities.

- **Timeline & Planning**
  - **Daily Timeline**: Visual representation of tasks for the day.
  - **Agenda View**: Quick overview of upcoming items.
  - **Focus Mode**: Dedicated interface for distraction-free work.
  - **Review System**: Weekly/Daily review flows to stay on track.

- **UI/UX**
  - **Premium Design**: Polished UI with custom themes (Light & Dark mode).
  - **Fluid Navigation**: Persistent bottom navigation with smooth transitions.
  - **Gestures**: Double-tap back to exit, swipe actions.
  - **Animations**: Subtle micro-interactions and transitions using `FadePageRoute`.

## 🏗 Architecture

Synq is built using a **Feature-First Architecture** combined with **Riverpod** for state management and **Firebase** for the backend.

### Project Structure (`lib/`)

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
│   ├── tasks/              # Task management logic
│   ├── timeline/           # Daily timeline view
│   ├── review/             # Review system logic
│   ├── shell/              # Main app shell (Bottom Nav)
│   ├── list/               # List handling logic
│   ├── agenda/             # Agenda view
│   └── focus/              # Focus mode
│
└── main.dart               # Entry point & App initialization
```

### Key Technologies

*   **State Management**: [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod)
    *   Used for dependency injection and state management across the app.
    *   Leverages `StateNotifierProvider`, `StreamProvider`, and `Provider` for reactive UI updates.
*   **Backend**: [Firebase](https://firebase.google.com/)
    *   **Authentication**: Manages user identity.
    *   **Cloud Firestore**: Real-time NoSQL database for syncing tasks, notes, and user data.
    *   **Storage**: For storing user assets (images/attachments).
*   **Local Storage**: [Hive](https://pub.dev/packages/hive)
    *   Used for local caching and preferences (e.g., theme settings).
*   **Navigation**:
    *   Standard `Navigator` 2.0 concepts wrapped in a shell-base structure.
    *   `IndexedStack` in `MainShell` maintains the state of each tab.
    *   Custom `FadePageRoute` for smooth screen transitions.

### Data Flow

1.  **Repository Pattern**: Each feature has a `data` layer (e.g., `FirestoreNotesRepository`) that handles direct communication with APIs/Firebase.
2.  **Providers/Notifiers**: The `presentation` layer interacts with data through Riverpod providers (e.g., `NotesNotifier`), which abstract the business logic.
3.  **UI**: Widgets consume these providers using `ConsumerWidget` to rebuild reactively when state changes.

## 🛠 Getting Started

### Prerequisites

- Flutter SDK (version ^3.10.7 or higher)
- Dart SDK
- Firebase Project setup

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Ankitkumar72/task_app.git
    cd task_app
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    *   This project relies on `firebase_options.dart`. Ensure you have configured your Firebase project using the FlutterFire CLI.
    *   Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective platform directories if manual setup is required, though the CLI usually handles this.

4.  **Run the App**:
    ```bash
    flutter run
    ```

## 📦 Dependencies

Key packages used in this project:

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State Management |
| `firebase_core/auth/cloud_firestore` | Backend Integration |
| `google_sign_in` | Google Authentication |
| `hive` / `hive_flutter` | Local Database |
| `intl` | Date/Time Formatting |
| `uuid` | Unique ID generation |
| `google_fonts` | Typography |
| `flutter_local_notifications` | Local Notifications |

## 🤝 Contributing

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request