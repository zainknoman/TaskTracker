# TaskFlow Pro

A modern multi-tenant task and work management platform built with **Vanilla JavaScript, ES Modules, and Supabase**.

TaskFlow Pro provides workspace-based task management, project organization, team collaboration, role-based access control, and real-time updates through Supabase.

---

## ✨ Features

### Workspace Management

* Create and manage workspaces
* Workspace member management
* Owner and member roles
* Workspace-level data isolation
* Invitation and membership workflows

### Project Management

* Create and manage projects
* Project status and categorization
* Project ownership
* Project-level task organization
* Project filtering and navigation

### Task Management

* Create, update, and delete tasks
* Task status management
* Task priorities
* Task assignment
* Due dates
* Project association
* Task filtering and search
* Task details and activity

### Collaboration

* Workspace members
* Task assignment
* Shared project visibility
* Real-time updates
* Role-based permissions

### Authentication

* Supabase Authentication
* Email/password authentication
* Session management
* Protected application routes
* Workspace-aware authorization

### Security

* Supabase Row Level Security (RLS)
* Workspace-level data isolation
* Role-based authorization
* Client-side public/anonymous key usage
* No service-role credentials in the browser

---

## 🏗️ Technology Stack

| Area            | Technology                    |
| --------------- | ----------------------------- |
| Frontend        | Vanilla JavaScript            |
| Language        | JavaScript / ES Modules       |
| Styling         | CSS                           |
| Backend         | Supabase                      |
| Database        | PostgreSQL                    |
| Authentication  | Supabase Auth                 |
| Authorization   | PostgreSQL Row Level Security |
| Realtime        | Supabase Realtime             |
| Package Manager | npm                           |
| Mobile Client   | Flutter                       |
| Repository      | Git / GitHub                  |

---

## 📁 Project Structure

```text
TaskTracker/
│
├── index.html
├── config.example.js
├── config.js
│
├── css/
│   └── ...
│
├── js/
│   ├── ...
│   └── modules/
│       └── ...
│
├── scripts/
│   └── ...
│
├── docs/
│   └── ...
│
├── flutter_app/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── README.md
│
└── README.md
```

The exact directory structure may evolve as the application develops.

---

# 🚀 Getting Started

## 1. Clone the Repository

```bash
git clone https://github.com/zainknoman/TaskTracker.git
cd TaskTracker
```

Switch to the development branch if required:

```bash
git checkout dev
```

---

## 2. Create a Supabase Project

Create your own Supabase project.

The application requires:

* Supabase project URL
* Supabase anonymous/public key
* PostgreSQL database
* Supabase Authentication
* Row Level Security
* Realtime where required

**Do not use another developer's Supabase project.**

---

## 3. Configure the Application

Create your local configuration file from the example:

```bash
copy config.example.js config.js
```

On macOS/Linux:

```bash
cp config.example.js config.js
```

Configure it with your own Supabase credentials.

Example:

```javascript
window.APP_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseKey: 'YOUR_SUPABASE_ANON_KEY'
};
```

### Important

`config.js` is intended for local development and should **not** be committed if it contains environment-specific configuration.

The Supabase **service-role key must never be placed in frontend code**.

---

# 🗄️ Database

TaskFlow Pro uses **PostgreSQL through Supabase**.

The database is designed around workspace isolation and includes entities such as:

* Users
* Workspaces
* Workspace memberships
* Projects
* Tasks
* Task assignments
* Related task/project metadata
* Authentication identities

The exact schema may change as new application features are introduced.

---

## 🔐 Row Level Security

Supabase Row Level Security is used to enforce authorization at the database level.

The application should ensure that users can only access data they are authorized to access through their workspace membership and assigned permissions.

When adding new tables or relationships:

1. Define the required relationships.
2. Add appropriate RLS policies.
3. Test access using different user roles.
4. Verify that users cannot access another workspace's data.
5. Never rely solely on frontend authorization.

---

# 👥 Roles

The application supports workspace-based access control.

Typical roles include:

| Role   | Description                           |
| ------ | ------------------------------------- |
| Owner  | Full workspace administration         |
| Member | Access based on workspace permissions |

Additional roles or permission levels may be introduced as the application evolves.

---

# 🧪 Test Accounts

For local development, use **disposable test accounts only**.

Example:

| Account                        | Role             | Password    |
| ------------------------------ | ---------------- | ----------- |
| `alice.owner@tasktracker.test` | Owner            | `Test1234!` |
| `bob.member@tasktracker.test`  | Member           | `Test1234!` |
| `carol.guest@tasktracker.test` | Member/Test User | `Test1234!` |
| `dave.owner@tasktracker.test`  | Owner            | `Test1234!` |
| `erin.member@tasktracker.test` | Member           | `Test1234!` |

These accounts are intended for development/testing only.

### Production

Do not use the example test credentials in production.

Create separate production users with secure passwords and appropriate authentication policies.

---

# 🧑‍💻 Development

Install dependencies:

```bash
npm install
```

Start the development environment according to the project's configured scripts.

For example:

```bash
npm run dev
```

If the repository does not define a development script, serve the application using your preferred local static server.

---

# 📱 Flutter Application

The repository also contains a Flutter client under:

```text
flutter_app/
```

See:

```text
flutter_app/README.md
```

for mobile-specific setup instructions.

The Flutter application should use the developer's own Supabase configuration.

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

For production builds, configure credentials through the appropriate build/environment mechanism rather than committing environment-specific values to source control.

---

# 🔧 Configuration

The repository should contain a safe configuration template such as:

```text
config.example.js
```

Example:

```javascript
window.APP_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseKey: 'YOUR_SUPABASE_ANON_KEY'
};
```

Never commit:

* Supabase service-role keys
* Database passwords
* API secrets
* Private authentication credentials
* Personal access tokens
* Production-only credentials
* Private environment files

---

# 🛡️ Security Guidelines

Before pushing changes to GitHub, verify that the repository does not contain:

```text
Passwords
API secrets
Service-role keys
Private tokens
Production credentials
Personal email addresses
Private database information
Private Supabase dashboard URLs
Local filesystem paths
Private screenshots
Private customer/user information
```

Use placeholders in documentation:

```text
YOUR_PROJECT_REF
YOUR_SUPABASE_ANON_KEY
YOUR_DATABASE_PASSWORD
your-email@example.com
```

---

# 📊 Data Isolation

TaskFlow Pro is designed as a multi-tenant application.

Each workspace should have isolated data.

The expected authorization model is:

```text
User
  │
  └── Workspace Membership
          │
          ├── Projects
          │      └── Tasks
          │
          └── Workspace Data
```

Application code should never assume that a user is authorized simply because an object ID is known.

Authorization must be enforced through the database policies and server-side logic where applicable.

---

# ⚡ Realtime

Supabase Realtime can be used for application areas where users need immediate updates.

Potential realtime use cases include:

* Task status changes
* Task assignment changes
* Project updates
* Workspace activity
* Collaboration events

Realtime functionality should always respect the application's authorization model.

---

# 🧪 Testing

Before submitting changes, test:

### Authentication

* Sign up
* Sign in
* Sign out
* Session persistence
* Invalid credentials
* Protected routes

### Workspace

* Create workspace
* Access workspace
* Add members
* Remove members
* Verify workspace isolation

### Projects

* Create project
* Update project
* Delete project
* Verify project access

### Tasks

* Create task
* Edit task
* Assign task
* Change status
* Set priority
* Set due date
* Delete task

### Security

Test with users from different workspaces and verify that unauthorized records cannot be accessed.

---

# 🐛 Troubleshooting

## Supabase Connection Problems

Verify:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

and confirm that the Supabase project is running.

Do not copy production credentials from another environment.

---

## Authentication Problems

Check:

* Supabase Auth configuration
* Redirect URLs
* Email authentication settings
* Browser console errors
* RLS policies

---

## Database Permission Problems

Check:

* RLS is enabled
* Appropriate policies exist
* The authenticated user belongs to the expected workspace
* Foreign-key relationships are correct
* Queries are filtering by the appropriate workspace context

---

# 📚 Documentation

Project documentation can be found under:

```text
docs/
```

Documentation may include:

* Architecture information
* Database information
* Development notes
* Feature specifications
* Implementation plans
* Testing documentation

Documentation should use generic examples and must not contain production credentials or unnecessary personal information.

---

# 🤝 Contributing

1. Fork the repository.
2. Create a feature branch.

```bash
git checkout -b feature/my-feature
```

3. Make your changes.
4. Test the changes locally.
5. Review the diff for accidental secrets or personal information.

```bash
git diff
```

6. Commit the changes.

```bash
git add .
git commit -m "Add my feature"
```

7. Push the branch.

```bash
git push origin feature/my-feature
```

8. Open a pull request.

---

# 🔒 Before Every Git Push

Run a final privacy/security check.

Look for:

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

Some matches may be legitimate examples, but every match should be reviewed before committing.

Also review:

* Screenshots
* CSV/JSON exports
* Seed data
* Documentation
* Configuration files
* `.env` files
* Local paths
* Git history

---

# 🌱 Environment Separation

Use separate Supabase projects/environments for:

```text
Development
Testing
Staging
Production
```

Do not use a production database for local experimentation or repository examples.

---

# 📄 License

Add the project's chosen license here.

Example:

```text
MIT License
```

If a different license is selected, replace the above accordingly.

---

# 📌 Project Status

TaskFlow Pro is under active development.

Features, database structures, APIs, authentication flows, and UI components may change between versions.

For the latest implementation details, refer to the source code and documentation in the repository.

---

## ⚠️ Important Notice

This repository is intended to contain **source code and generic development documentation only**.

Do not commit:

* Real user credentials
* Production passwords
* Private API keys
* Supabase service-role keys
* Database credentials
* Personal user information
* Private customer information
* Private screenshots
* Unnecessary production infrastructure details

Use environment-specific configuration and disposable test data for development.

---

## 👤 Maintainer

TaskFlow Pro is maintained as an independent software project.

For project contributions, issues, and technical discussions, use the GitHub repository's standard issue and pull-request workflows.
