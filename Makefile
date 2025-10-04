# Vaalin Makefile
# Standard development commands for SwiftUI macOS project

.PHONY: help format lint test build clean docs

# Default target
help:
	@echo "Vaalin Development Commands:"
	@echo ""
	@echo "  make format    - Auto-fix SwiftLint issues"
	@echo "  make lint      - Check SwiftLint compliance (CI mode)"
	@echo "  make test      - Run all tests with coverage"
	@echo "  make build     - Build for development (Debug configuration)"
	@echo "  make clean     - Clean build artifacts and derived data"
	@echo "  make docs      - Generate DocC documentation"
	@echo ""
	@echo "Requirements:"
	@echo "  - Xcode 16.0+ (for macOS 26 APIs and Swift 5.9+)"
	@echo "  - SwiftLint: brew install swiftlint"

# Auto-fix SwiftLint issues
format:
	@echo "🔧 Running SwiftLint auto-fix..."
	swiftlint --fix

# Check SwiftLint compliance (fails on violations)
lint:
	@echo "🔍 Checking SwiftLint compliance..."
	swiftlint

# Run all tests with code coverage
test:
	@echo "🧪 Running tests with coverage..."
	xcodebuild test \
		-scheme Vaalin \
		-destination 'platform=macOS' \
		-enableCodeCoverage YES \
		-resultBundlePath TestResults.xcresult
	@echo "✅ Tests complete. View coverage: xcrun xccov view --report TestResults.xcresult"

# Build for development (Debug configuration)
build:
	@echo "🔨 Building Vaalin (Debug)..."
	xcodebuild build \
		-scheme Vaalin \
		-destination 'platform=macOS' \
		-configuration Debug

# Clean build artifacts and derived data
clean:
	@echo "🧹 Cleaning build artifacts..."
	xcodebuild clean -scheme Vaalin
	@echo "🧹 Cleaning derived data..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/Vaalin-*
	@echo "🧹 Cleaning test results..."
	rm -rf TestResults.xcresult
	@echo "✅ Clean complete"

# Generate DocC documentation
docs:
	@echo "📚 Generating DocC documentation..."
	xcodebuild docbuild \
		-scheme Vaalin \
		-destination 'platform=macOS'
	@echo "✅ Documentation built. Open in Xcode: Product > Build Documentation"
