# Synq Architecture Overview

Below is a detailed Mermaid diagram illustrating the architecture of the Synq app, based on its Feature-First structure, Riverpod state management, and Firebase data layer.

```mermaid
graph TD
    %% Define Styles
    classDef ui fill:#4A90E2,stroke:#357ABD,stroke-width:2px,color:#fff;
    classDef state fill:#F5A623,stroke:#D08C1F,stroke-width:2px,color:#fff;
    classDef controller fill:#7ED321,stroke:#64AD1A,stroke-width:2px,color:#fff;
    classDef repo fill:#9013FE,stroke:#720ECA,stroke-width:2px,color:#fff;
    classDef ext fill:#D0021B,stroke:#A10115,stroke-width:2px,color:#fff;
    
    subgraph UI_Layer ["UI Layer (Widgets / Screens)"]
        direction TB
        AuthScreen[Auth & Login]:::ui
        HomeScreen[Home Dashboard / Next Up]:::ui
        NotesScreen[Notes & Folders]:::ui
        TimelineScreen[Timeline & Planner]:::ui
        FocusScreen[Focus Mode & Timer]:::ui
        ProfileScreen[Profile & Subscription]:::ui
        ShellNavigation[Main Shell / Bottom Navigation]:::ui
        
        ShellNavigation --> HomeScreen
        ShellNavigation --> NotesScreen
        ShellNavigation --> TimelineScreen
        ShellNavigation --> ProfileScreen
    end

    subgraph State_Layer ["State Management (Riverpod Providers)"]
        direction TB
        AuthProvider[Auth State Provider]:::state
        HomeProvider[Dashboard State Provider]:::state
        NoteProvider[Notes & Categories State]:::state
        TaskProvider[Task & Timeline State]:::state
        FocusProvider[Focus Timer State]:::state
        ProfileProvider[User Profile State]:::state
    end

    subgraph Logic_Layer ["Controllers / Business Logic (Notifiers)"]
        direction TB
        AuthNotifier[Auth Notifier]:::controller
        NotesNotifier[Notes Notifier]:::controller
        TaskNotifier[Task Notifier]:::controller
        FocusNotifier[Focus Timer Logic]:::controller
        ProfileNotifier[Profile/Subscription Logic]:::controller
    end

    subgraph Data_Layer ["Repository Layer"]
        direction TB
        AuthRepo[Firebase Auth Repository]:::repo
        FirestoreNotesRepo[Firestore Notes/Tasks Repository]:::repo
        FirestoreUserRepo[Firestore User/Subscription Repository]:::repo
        StorageRepo[Firebase Storage Repository]:::repo
        LocalRepo[Hive Local Storage Repository]:::repo
    end

    subgraph External_Services ["External Services & Backend"]
        direction TB
        FirebaseAuth((Firebase\nAuthentication)):::ext
        FirestoreDB[(Cloud\nFirestore)]:::ext
        FirebaseStorage[(Firebase\nStorage)]:::ext
        HiveDB[(Hive\nLocal DB)]:::ext
        Notifications((Local\nNotifications)):::ext
    end

    %% UI to State Bindings
    AuthScreen -.-> AuthProvider
    HomeScreen -.-> HomeProvider
    HomeScreen -.-> TaskProvider
    NotesScreen -.-> NoteProvider
    TimelineScreen -.-> TaskProvider
    FocusScreen -.-> FocusProvider
    ProfileScreen -.-> ProfileProvider

    %% State to Logic
    AuthProvider <--> AuthNotifier
    NoteProvider <--> NotesNotifier
    TaskProvider <--> TaskNotifier
    FocusProvider <--> FocusNotifier
    ProfileProvider <--> ProfileNotifier
    HomeProvider <--> TaskNotifier

    %% Logic to Data Layer
    AuthNotifier --> AuthRepo
    NotesNotifier --> FirestoreNotesRepo
    TaskNotifier --> FirestoreNotesRepo
    TaskNotifier --> LocalRepo
    FocusNotifier --> FirestoreNotesRepo
    ProfileNotifier --> FirestoreUserRepo
    NotesNotifier --> StorageRepo
    FocusNotifier --> Notifications

    %% Data Layer to External Services
    AuthRepo --> FirebaseAuth
    FirestoreNotesRepo --> FirestoreDB
    FirestoreUserRepo --> FirestoreDB
    StorageRepo --> FirebaseStorage
    LocalRepo --> HiveDB
```
