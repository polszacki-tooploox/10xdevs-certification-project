# Tech Stack - BrewGuide

## Overview

This document outlines the technology stack chosen for BrewGuide MVP and the rationale behind each decision. The stack prioritizes maintainability, proper conflict resolution, and alignment with iOS best practices.

## Core Technologies

### iOS Application Layer

#### Swift
- **Version**: Swift 6.0 (for Observation framework support)
- **Rationale**: 
  - Native iOS language with strong type safety
  - Excellent performance for timer operations and UI updates
  - Modern concurrency support (async/await)
  - Industry standard for iOS development

#### SwiftUI
- **Version**: iOS 21.0 (for Observation framework)
- **Rationale**:
  - Declarative UI framework ideal for step-by-step brew flow
  - Reactive updates for timer displays and state changes
  - Built-in accessibility support (Dynamic Type, VoiceOver)
  - Reduces boilerplate compared to UIKit
  - Kitchen-proof UI with large touch targets easily achievable

#### Observation Framework
- **Rationale**:
  - Modern, lightweight state management
  - Automatic view updates when observed properties change
  - Better performance than ObservableObject for simple state
  - Cleaner syntax than @Published properties
  - Well-suited for timer state and brew flow management

#### Swift Concurrency (async/await)
- **Rationale**:
  - Native support for asynchronous operations (timers, sync)
  - Structured concurrency prevents common threading issues
  - Clean error handling with async/await
  - Essential for non-blocking sync operations
  - Timer management benefits from Task-based concurrency

### Data Persistence & Sync

#### CloudKit
- **Rationale**:
  - Native Apple solution for cloud sync
  - Better conflict resolution than raw iCloud
  - Structured data model with CKRecord
  - Automatic handling of network conditions
  - Free for users (within iCloud storage limits)
  - End-to-end encryption support
  - Better debugging and monitoring than raw iCloud
  - Supports custom conflict resolution strategies

#### Core Data (Local Storage)
- **Rationale**:
  - Primary local persistence layer
  - Works seamlessly with CloudKit via NSPersistentCloudKitContainer
  - Handles offline-first architecture requirement
  - Type-safe data models
  - Efficient querying for brew log lists
  - Automatic CloudKit sync integration

#### Keychain Services
- **Rationale**:
  - Secure storage for Sign in with Apple credentials
  - Encrypted at rest
  - iOS standard for sensitive data

### Authentication

#### Sign in with Apple
- **Rationale**:
  - PRD requirement
  - Privacy-focused authentication
  - No additional backend required
  - Seamless integration with CloudKit user identity
  - Supports optional authentication (users can use app without signing in)

### CI/CD & Development Tools

#### GitHub Actions
- **Rationale**:
  - Free for public repositories
  - Good integration with GitHub
  - Supports iOS builds and testing
  - Can automate TestFlight deployments
  - Sufficient for MVP needs

