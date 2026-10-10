# AutoServe Setup Guide

## Prerequisites

- Flutter SDK installed (stable channel)
- Git installed
- VS Code or Android Studio

## Steps

1. Clone the repo
   git clone https://github.com/your-org/autoserve.git
   cd autoserve

2. Checkout dev branch
   git checkout dev

3. Navigate to your app folder
   cd apps/customer (or apps/dashboard)

4. Get Flutter packages
   flutter pub get

5. Create your .env file
   Copy .env.example to .env in your app folder
   Ask the project maintainer for the actual Supabase URL and anon key
   Never commit your .env file

6. Run the app
   flutter run -d chrome

## Shared Package

Both apps depend on the shared package at /shared.
Always import shared code using: import 'package:shared/shared.dart';
Never copy a model or widget into your own app folder — if something is missing from shared/, add it there.

## Branch Workflow

1. Pull latest dev before starting work: git checkout dev && git pull
2. Create your feature branch: git checkout -b feature/your-feature-name
3. Work, commit often with clear messages
4. Push your branch: git push origin feature/your-feature-name
5. Open a Pull Request into dev on GitHub
6. Tag a teammate to review
7. Merge after approval

## Questions / Blockers

Post in the team WhatsApp immediately. Don't sit stuck for more than 30 minutes.
