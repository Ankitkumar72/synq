# Synq Project Structure

This document outlines the folder architecture and internal module structure of the Synq Flutter application. The project is organized using a **Feature-First Architecture**, ensuring modularity and clean separation of concerns.

## Directory Overview (`lib/`)

The `lib/` directory is the core of the application, separated into two main areas: `core` and `features`.

### 1. Core (`lib/core/`)
Contains shared resources, utilities, and configurations used across the entire application.
- **`navigation/`**: Global navigation helpers and routing configurations.
- **`providers/`**: App-wide providers (e.g., Firebase error handling, global state).
- **`services/`**: Wrappers for external services (Firebase, Notifications).
- **`theme/`**: App theme definitions including Colors, TextStyles, and ThemeData.
- **`utils/`**: Helper formatting functions and constants.
- **`widgets/`**: Reusable generic UI widgets (e.g., custom buttons, text fields).

### 2. Features (`lib/features/`)
Each feature module encapsulates its own data, domain logic, and presentation layers.

#### `auth/` (Authentication)
Handles User Login, Signup, and Session Management.
- `data/`: Authentication repositories and Firebase wrappers.
- `presentation/`: Login screens, signup screens, and auth-state widgets.
- *See [Architecture Diagram](./auth.md)*

#### `focus/` (Focus Mode)
Handles the distraction-free work timer and task tracking.
- `presentation/`: Focus timer UI, visualizations (`WaveformGraph`, `CircularTimer`).
- `services/`: Timer logic and system integrations.
- *See [Architecture Diagram](./focus.md)*

#### `home/` (Dashboard)
The main entry point after login, showing the "Next Up" overview.
- `presentation/`: Dashboard UI, dynamic task summaries, and welcome widgets.
- *See [Architecture Diagram](./home.md)*

#### `notes/` (Note Taking & Folders)
Handles the creation, editing, and synchronization of Notes and Folders.
- `data/`: Repositories, Local DB (`Hive`), Firebase Sync (`FirebaseSyncCoordinator`).
- `domain/`: Note and Folder models.
- `presentation/`: Note editors, folder grids, and list views.
- `utils/`: Editor-specific utilities (e.g., Markdown handling).
- *See [Architecture Diagram](./notes.md)*

#### `profile/` (User Profile & Subscription)
Manages user settings, stats, and upgrading to Pro.
- `presentation/`: Profile settings UI, subscription tier comparisons, and payment screens.
- *See [Architecture Diagram](./profile.md)*

#### `shell/` (App Shell)
The persistent layout structure framing the main application.
- Contains the `MainShell` using an `IndexedStack` and the `BottomNavigationBar`.

#### `timeline/` (Daily Timeline)
Visual representation of daily tasks, including regular and recurring items.
- `data/`: Timeline event repositories.
- `domain/`: Timeline event models.
- `presentation/`: Daily planner UI, Weekly Focus modal, and scheduling flows.
- *See [Architecture Diagram](./timeline.md)*

---

