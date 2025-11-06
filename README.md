# first_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Features

### Handwriting Recognition for Spelling Practice

The app now includes a handwriting zone where users can practice spelling by writing letters with their finger or stylus.

#### How to Use Handwriting Feature:

1. **Navigate to Practice Page**: Open the practice page in the app
2. **Look at the Handwriting Zone**: At the bottom of the screen, you'll see a handwriting area
3. **Write the Letter**: Use your finger to draw the required letter (starting with 'B' for "beautiful")
4. **Recognition**: The app will automatically recognize when you've written the correct letter shape
5. **Success Feedback**: When recognized correctly, you'll see "✓ 识别成功！" and the letter will be filled in above

#### Handwriting Recognition Algorithm:

The app uses a simple shape recognition algorithm that looks for:
- **Starting Position**: Letters should start from the bottom of the writing area
- **Direction**: Upward movement for most letters
- **Shape Characteristics**: Specific curves and lines that match the letter's form
- **Size Requirements**: Minimum width and height thresholds

Currently optimized for recognizing the letter 'B' with these characteristics:
- Starts from bottom
- Moves upward
- Has a rightward curve in the middle
- Maintains a vertical line on the left side