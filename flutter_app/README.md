# TaskFlow Pro — Flutter App

Flutter client for **TaskFlow Pro**, a multi-tenant task and work management platform.

The Flutter application connects to a Supabase backend and provides mobile access to workspace, project, task, authentication, and collaboration functionality.

---

## ✨ Features

### Authentication

* Supabase authentication
* Email/password sign-in
* Session persistence
* Sign-out
* Authentication state management
* Protected application flows

### Workspace

* Workspace access
* Workspace membership
* Role-aware functionality
* Workspace data isolation

### Projects

* View projects
* Project details
* Project organization
* Project-related task access

### Tasks

* View tasks
* Task details
* Task status
* Task priority
* Task assignment
* Due dates
* Project association
* Task updates

### Collaboration

* Workspace members
* Assigned tasks
* Shared project information
* Realtime updates where supported

---

# 🏗️ Technology Stack

| Area             | Technology                            |
| ---------------- | ------------------------------------- |
| Framework        | Flutter                               |
| Language         | Dart                                  |
| Backend          | Supabase                              |
| Database         | PostgreSQL                            |
| Authentication   | Supabase Auth                         |
| Authorization    | Row Level Security                    |
| Realtime         | Supabase Realtime                     |
| State Management | Project implementation                |
| Platforms        | Android / iOS / Desktop as configured |

---

# 📁 Project Structure

```text
flutter_app/
│
├── lib/
│   ├── core/
│   │   ├── ...
│   │   └── supabase_config.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── workspace/
│   │   ├── projects/
│   │   ├── tasks/
│   │   └── ...
│   │
│   ├── models/
│   ├── services/
│   ├── widgets/
│   └── main.dart
│
├── android/
├── ios/
├── web/
├── test/
├── pubspec.yaml
└── README.md
```

The exact structure may evolve as the application develops.

---

# 🚀 Getting Started

## Prerequisites

Install:

* Flutter SDK
* Dart SDK included with Flutter
* Android Studio or Xcode for mobile development
* Git

Verify the Flutter installation:

```bash
flutter doctor
```

---

## 1. Clone the Repository

```bash
git clone https://github.com/zainknoman/TaskTracker.git
cd TaskTracker/flutter_app
```

If you are already inside the repository:

```bash
cd flutter_app
```

---

# 2. Install Dependencies

Run:

```bash
flutter pub get
```

---

# 3. Configure Supabase

The Flutter application requires a Supabase project.

Create your **own Supabase project** for development.

You will need:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Example:

```text
https://YOUR_PROJECT_REF.supabase.co
```

and:

```text
YOUR_SUPABASE_ANON_KEY
```

Do not use credentials belonging to another developer or environment.

---

# 🔐 Supabase Configuration

The application supports environment-based configuration using Dart defines.

Recommended approach:

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

For PowerShell:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

For macOS/Linux:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

---

# ⚠️ Important Configuration Rule

Do not commit production or private environment credentials to GitHub.

Never place the following in source control:

```text
Database passwords
Supabase service-role keys
Private API keys
Authentication secrets
Private tokens
Production credentials
```

The Supabase **anonymous/public key** is intended for client-side use when protected by appropriate Row Level Security policies.

The **service-role key must never be included in the Flutter application**.

---

# 📱 Running the Application

List available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

Or specify a device:

```bash
flutter run -d <device-id>
```

---

# 🧪 Testing

Run all Flutter tests:

```bash
flutter test
```

Run tests with additional output:

```bash
flutter test -r expanded
```

For a specific test:

```bash
flutter test test/<test_file>.dart
```

---

# 🔍 Static Analysis

Run Flutter/Dart analysis:

```bash
flutter analyze
```

The project should ideally have no analyzer errors before changes are committed.

---

# 🏗️ Building

## Android

Build an APK:

```bash
flutter build apk
```

Build an Android App Bundle:

```bash
flutter build appbundle
```

---

## iOS

On macOS:

```bash
flutter build ios
```

iOS distribution also requires the appropriate Apple developer configuration and signing setup.

---

## Web

If web support is enabled:

```bash
flutter build web
```

---

# 🗄️ Backend

The Flutter application uses the same application backend architecture as the main TaskFlow Pro application.

High-level architecture:

```text
┌──────────────────────┐
│    Flutter Client    │
└──────────┬───────────┘
           │
           │ Supabase Client
           ▼
┌──────────────────────┐
│       Supabase       │
├──────────────────────┤
│ Authentication       │
│ PostgreSQL           │
│ Row Level Security   │
│ Realtime             │
└──────────────────────┘
```

The mobile application should connect to the developer's configured Supabase environment.

---

# 🔐 Security Model

The application relies on Supabase authentication and database authorization.

The expected security model is:

```text
User
 │
 ▼
Supabase Authentication
 │
 ▼
Authenticated Session
 │
 ▼
Workspace Membership
 │
 ▼
Row Level Security
 │
 ├── Workspace
 ├── Projects
 └── Tasks
```

Database authorization should not depend exclusively on Flutter UI checks.

RLS policies must prevent users from accessing records outside their authorized workspace.

---

# 👥 Workspace Roles

TaskFlow Pro uses workspace-based permissions.

Typical roles include:

| Role   | Description                               |
| ------ | ----------------------------------------- |
| Owner  | Full workspace administration             |
| Member | Access according to workspace permissions |

The exact permission model may evolve with future versions.

---

# 🧪 Development Test Accounts

Use **disposable development accounts only**.

Example test accounts:

| Account                        | Role      | Password    |
| ------------------------------ | --------- | ----------- |
| `alice.owner@tasktracker.test` | Owner     | `Test1234!` |
| `bob.member@tasktracker.test`  | Member    | `Test1234!` |
| `carol.guest@tasktracker.test` | Test User | `Test1234!` |
| `dave.owner@tasktracker.test`  | Owner     | `Test1234!` |
| `erin.member@tasktracker.test` | Member    | `Test1234!` |

These accounts are examples for development/testing.

**Never use these credentials for production.**

For production environments, create separate users with secure credentials.

---

# 🔄 Realtime

Where enabled, Supabase Realtime can provide immediate updates for application data.

Possible realtime use cases include:

* Task changes
* Project changes
* Assignment changes
* Workspace activity
* Collaboration events

Realtime subscriptions must remain subject to the application's authorization model.

---

# 🧩 Application Configuration

If the application contains:

```text
lib/core/supabase_config.dart
```

verify that it does not contain hard-coded credentials belonging to a private or production environment.

Prefer environment configuration such as:

```dart
const supabaseUrl =
    String.fromEnvironment('SUPABASE_URL');

const supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY');
```

with values supplied during development/build time.

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

---

# 🛡️ Privacy Checklist

Before committing Flutter changes, check the repository for:

```text
@gmail.com
@hotmail.com
@yahoo.com
@company.com
supabase.co
service_role
password
secret
token
api_key
apikey
private_key
BEGIN PRIVATE KEY
```

Review every match before committing.

Also check:

* Screenshots
* Debug logs
* Test fixtures
* JSON files
* CSV files
* Seed data
* Configuration files
* Documentation
* Local filesystem paths
* Generated files

---

# 📸 Screenshots

Screenshots included in project documentation should use:

* Generic user names
* Disposable test accounts
* Generic workspaces
* Placeholder data

Do not publish screenshots containing:

* Real email addresses
* Personal names where unnecessary
* Production customer information
* Private workspace information
* Authentication tokens
* Database credentials
* Private infrastructure details

---

# 🐛 Troubleshooting

## Flutter Dependencies

If dependencies are unavailable:

```bash
flutter pub get
```

Then verify:

```bash
flutter doctor
```

---

## Supabase Connection

Check that the following values are configured:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Verify that the Supabase project is running and that the database schema is available.

---

## Authentication Issues

Check:

* Supabase Auth configuration
* Email authentication settings
* Redirect URLs where applicable
* Authentication session state
* Network connectivity
* Supabase project configuration

---

## Permission / RLS Errors

If data cannot be loaded:

1. Confirm the user is authenticated.
2. Confirm the user belongs to the expected workspace.
3. Check the relevant RLS policies.
4. Verify foreign-key relationships.
5. Verify that the authenticated user is allowed to access the requested records.

Do not disable RLS as a workaround.

---

# 🧹 Clean Build

If Flutter is behaving unexpectedly, try:

```bash
flutter clean
flutter pub get
flutter run
```

If necessary, also verify:

```bash
flutter doctor
```

---

# 🔧 Development Workflow

Recommended workflow:

```text
1. Pull latest changes
        ↓
2. Install/update dependencies
        ↓
3. Configure local Supabase environment
        ↓
4. Run application
        ↓
5. Implement changes
        ↓
6. Run flutter analyze
        ↓
7. Run flutter test
        ↓
8. Review Git diff
        ↓
9. Check for secrets/private information
        ↓
10. Commit and push
```

---

# 🤝 Contributing

1. Create a feature branch:

```bash
git checkout -b feature/my-feature
```

2. Make your changes.

3. Run:

```bash
flutter analyze
flutter test
```

4. Review the changes:

```bash
git diff
```

5. Check for accidental credentials or personal information.

6. Commit:

```bash
git add .
git commit -m "Add my feature"
```

7. Push:

```bash
git push origin feature/my-feature
```

8. Open a pull request.

---

# 🔒 Before Every Git Push

Perform a final privacy and security review.

Check for:

```text
Real email addresses
Real names
Production credentials
Supabase service-role keys
API secrets
Database passwords
Authentication tokens
Private URLs
Local Windows paths
Private screenshots
Customer/user data
```

The Flutter repository should contain only information appropriate for the intended repository visibility.

---

# 🌱 Environment Separation

For serious development and deployment, use separate backend environments:

```text
Development
    ↓
Testing
    ↓
Staging
    ↓
Production
```

The Flutter application should be configured against the appropriate environment during each build.

Do not use production credentials for local development.

---

# 📚 Related Documentation

The main project documentation is located in the repository root:

```text
../README.md
```

Additional project documentation may be available under:

```text
../docs/
```

Keep documentation generic and avoid committing environment-specific or personal information.

---

# 📌 Project Status

TaskFlow Pro Flutter is under active development.

Application screens, APIs, database structures, authentication flows, and mobile functionality may change between versions.

Refer to the source code and project documentation for the latest implementation details.

---

# ⚠️ Public Repository Notice

This repository is intended to contain **source code, technical documentation, and generic development examples**.

Do not commit:

* Real user credentials
* Production passwords
* Supabase service-role keys
* Private API keys
* Database credentials
* Personal user information
* Private customer information
* Authentication tokens
* Private screenshots
* Environment-specific secrets

Use environment variables, Dart defines, secure CI/CD configuration, and disposable test data instead.

---

## 👤 Maintainer

TaskFlow Pro is maintained as an independent software project.

For contributions, bug reports, and technical discussions, use the repository's GitHub issue and pull-request workflows.
