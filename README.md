# BrewGuide

An iOS app that improves home coffee brewing consistency by guiding beginner-to-intermediate brewers through a simple, timer-based V60 brew flow.

## Table of Contents

- [Project Description](#project-description)
- [Tech Stack](#tech-stack)
- [Getting Started Locally](#getting-started-locally)
- [Project Scope](#project-scope)
- [Project Status](#project-status)
- [License](#license)

## Project Description

BrewGuide is designed to help home coffee brewers achieve consistent results by providing:

- **Guided V60 Brewing Flow**: Step-by-step instructions with integrated timers for each brewing stage
- **Recipe Management**: Starter recipes that can be duplicated and customized with validation guardrails
- **Automatic Scaling**: Recipe quantities automatically adjust when you change coffee dose or target yield
- **Brew Logging**: Lightweight post-brew logging with ratings, taste tags, and optional notes
- **Cloud Sync** (optional): Sign in with Apple to sync recipes and logs across devices

The app is optimized for kitchen use with large, easy-to-tap controls, minimal typing requirements, and clear sequential steps that work well with wet hands and one-handed operation.

### Target User

Beginner-to-intermediate home brewers focused on repeatability and consistency, using standard equipment (grinder, 0.1g scale, kettle with temperature readout, V60-style dripper and filters).

## Tech Stack

### Platform & Language
- **iOS 26.0+**
- **Swift 6.2+**

### Frameworks & Libraries
- **SwiftUI** - All UI components (UIKit only when necessary)
- **Observation** (`@Observable`) - View model state management
- **Swift Concurrency** - Modern async/await, Task, actors, `@MainActor`
- **SwiftData** - Local persistence (offline-first)
- **CloudKit** - Optional cloud sync via private database (enabled after sign-in)
- **AuthenticationServices** - Sign in with Apple

### Development Tools
- **Xcode** (latest stable)
- **Swift Package Manager (SPM)** - Dependency management
- **SwiftLintPlugins** - Code quality and style enforcement
- **Swift Testing** - Unit testing framework

### Architecture

The project follows a **Domain-first MVVM** architecture:

- **Domain Layer**: Pure business rules and state transitions (no SwiftUI, no persistence)
- **UI Layer**: SwiftUI screens + view models using `@Observable`
- **Persistence Layer**: SwiftData models + repository pattern
- **Sync Layer**: CloudKit sync service (runs only when signed in and enabled)

The project structure uses feature-first grouping within these layers, with each feature containing its screen, view models, domain types, and persistence types grouped together.

## Getting Started Locally

### Prerequisites

- macOS with Xcode (latest stable version)
- iOS 26.0+ SDK
- Swift 6.2+
- Apple Developer account (for running on device and CloudKit)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "10xDevs project"
   ```

2. **Open the project**
   ```bash
   open BrewGuide/BrewGuide.xcodeproj
   ```

3. **Configure CloudKit** (optional, for sync functionality)
   - In Xcode, select the project target
   - Go to "Signing & Capabilities"
   - Add "CloudKit" capability
   - Ensure your Apple Developer account is configured

4. **Configure Sign in with Apple** (optional, for sync functionality)
   - In Xcode, select the project target
   - Go to "Signing & Capabilities"
   - Add "Sign in with Apple" capability

5. **Build and run**
   - Select a simulator or connected device
   - Press `Cmd + R` or click the Run button in Xcode

### Running Tests

The project uses Swift Testing for unit tests. To run tests:

- Press `Cmd + U` in Xcode, or
- Use the Test Navigator (⌘6) to run individual test cases

### Code Quality

The project includes SwiftLint for code quality enforcement. Ensure SwiftLint returns no warnings or errors before committing code.

## Project Status

**Status**: In Development (MVP)

## License

[License information to be added]

---

For detailed product requirements and user stories, see the [PRD documentation](.ai/prd.md).
