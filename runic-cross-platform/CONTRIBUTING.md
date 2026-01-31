# Contributing Guide

Thank you for considering contributing to Runic Cross-Platform! This guide will help you get started.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards others

## Getting Started

### Prerequisites

- Node.js 18+ and npm 9+
- Git
- For Android: Android Studio
- For Windows: Visual Studio 2022

### Setup Development Environment

```bash
# Fork and clone the repository
git clone https://github.com/yourusername/runic-cross-platform.git
cd runic-cross-platform

# Install dependencies
npm install

# Start development
npm start
```

## Development Guidelines

### Code Style

#### File Structure

Every file must follow this structure:

```typescript
/**
 * @file FileName.tsx
 * @description Brief description of the file's purpose.
 * More detailed explanation of what this file does and when to use it.
 */

// Imports (grouped: React, third-party, local)
import React from 'react';
import { View } from 'react-native';
import { useTheme } from '../hooks';

// Type definitions
interface ComponentProps {
  /** JSDoc comment for each prop */
  propName: string;
}

// Component implementation
export function Component({ propName }: ComponentProps) {
  // Implementation
}

// Styles (if using StyleSheet)
const styles = StyleSheet.create({
  // styles
});

// Default export (if needed)
export default Component;
```

#### File Size Limits

- **Maximum 400 lines per file**
- If a file exceeds 400 lines, split it into multiple files
- Group related functionality into separate modules

Example of splitting a large file:

```typescript
// Before (500 lines)
ProviderCard.tsx

// After (split into 3 files)
ProviderCard.tsx (200 lines)
ProviderCard.utils.ts (150 lines)
ProviderCard.styles.ts (150 lines)
```

#### JSDoc Comments

Every exported function, component, and type must have JSDoc comments:

```typescript
/**
 * Formats a number as currency with proper symbol and decimal places.
 *
 * @param amount - The numeric amount to format
 * @param currency - ISO 4217 currency code
 * @param showCents - Whether to show cents/decimal places
 * @returns Formatted currency string
 *
 * @example
 * formatCurrency(10.5, 'USD', true) // "$10.50"
 */
export function formatCurrency(
  amount: number,
  currency: CurrencyCode = 'USD',
  showCents = true
): string {
  // Implementation
}
```

#### TypeScript Rules

- Use strict mode (`strict: true`)
- No implicit `any` types
- Prefer interfaces over types for objects
- Use type inference where possible
- Define return types for functions

```typescript
// Good
interface User {
  id: string;
  name: string;
}

function getUser(id: string): User {
  // Implementation
}

// Bad
function getUser(id: any) {
  // Implementation
}
```

#### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Components | PascalCase | `ProviderCard` |
| Hooks | camelCase with `use` | `useTheme` |
| Functions | camelCase | `formatCurrency` |
| Types/Interfaces | PascalCase | `Provider` |
| Constants | UPPER_SNAKE_CASE | `STORAGE_KEYS` |
| Files | Match export name | `ProviderCard.tsx` |

#### Import Organization

Group imports in this order:

```typescript
// 1. React imports
import React, { useState, useEffect } from 'react';

// 2. React Native imports
import { View, Text, StyleSheet } from 'react-native';

// 3. Third-party libraries
import { useNavigation } from '@react-navigation/native';
import axios from 'axios';

// 4. Local imports (hooks, utils, types)
import { useTheme } from '../hooks';
import { formatCurrency } from '../utils';
import type { Provider } from '../types';

// 5. Relative imports
import { ProviderCard } from './ProviderCard';
```

### Component Guidelines

#### Component Structure

```typescript
/**
 * Component description
 */
export function ComponentName({ prop1, prop2 }: ComponentProps) {
  // 1. Hooks (state, context, custom hooks)
  const theme = useTheme();
  const [state, setState] = useState();

  // 2. Computed values (useMemo, useCallback)
  const computedValue = useMemo(() => {
    // computation
  }, [dependencies]);

  // 3. Effects
  useEffect(() => {
    // effect
  }, [dependencies]);

  // 4. Event handlers
  const handlePress = useCallback(() => {
    // handler
  }, [dependencies]);

  // 5. Render
  return (
    <View>
      {/* JSX */}
    </View>
  );
}
```

#### Props

- Always define prop types with interfaces
- Add JSDoc comments for each prop
- Provide default values when appropriate
- Use destructuring in function signature

```typescript
interface ButtonProps {
  /** Button label text */
  label: string;
  /** Click handler */
  onPress: () => void;
  /** Button variant (default: 'primary') */
  variant?: 'primary' | 'secondary';
  /** Disabled state */
  disabled?: boolean;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  disabled = false,
}: ButtonProps) {
  // Implementation
}
```

### State Management

#### When to Use Zustand Stores

Use stores for:
- Global application state
- Data that needs to persist
- State shared across multiple screens
- Complex state logic

Use local state for:
- UI-only state (e.g., modal open/closed)
- Form inputs
- Animation states

#### Store Structure

```typescript
interface StoreState {
  // State properties
}

interface StoreActions {
  // Action methods
}

export const useStore = create<StoreState & StoreActions>((set, get) => ({
  // Initial state
  property: initialValue,

  // Actions
  action: () => {
    // Implementation
  },
}));
```

### Testing

#### Unit Tests

Write tests for:
- Utility functions
- Store actions
- Service methods
- Validators

```typescript
describe('formatCurrency', () => {
  it('formats USD correctly', () => {
    expect(formatCurrency(10.5, 'USD')).toBe('$10.50');
  });

  it('hides cents when showCents is false', () => {
    expect(formatCurrency(10.5, 'USD', false)).toBe('$10');
  });
});
```

#### Component Tests

```typescript
describe('ProviderCard', () => {
  it('renders provider name', () => {
    const { getByText } = render(<ProviderCard provider={mockProvider} />);
    expect(getByText('OpenAI')).toBeTruthy();
  });

  it('calls onPress when tapped', () => {
    const onPress = jest.fn();
    const { getByTestId } = render(
      <ProviderCard provider={mockProvider} onPress={onPress} />
    );
    fireEvent.press(getByTestId('provider-card'));
    expect(onPress).toHaveBeenCalled();
  });
});
```

### Commits

#### Commit Message Format

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

Examples:
```
feat(providers): add MiniMax provider support

- Add MiniMax API client
- Update provider types
- Add MiniMax branding colors

Closes #123
```

### Pull Requests

#### PR Checklist

- [ ] Code follows style guidelines
- [ ] JSDoc comments added
- [ ] No files exceed 400 lines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No console.log statements
- [ ] TypeScript errors resolved
- [ ] ESLint warnings addressed

#### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How to test these changes

## Screenshots (if applicable)
Add screenshots for UI changes

## Related Issues
Fixes #123
```

### Code Review

#### As a Reviewer

- Review code within 24-48 hours
- Provide constructive feedback
- Approve if code meets standards
- Request changes with clear explanations

#### As an Author

- Respond to feedback promptly
- Make requested changes
- Explain decisions if disagreeing
- Thank reviewers for their time

### Documentation

Update documentation when:
- Adding new features
- Changing APIs
- Modifying architecture
- Adding dependencies

Files to update:
- `README.md` - User-facing documentation
- `ARCHITECTURE.md` - Architecture changes
- `CONTRIBUTING.md` - Development guidelines
- JSDoc comments - Code documentation

## Common Tasks

### Adding a New Component

1. Create file in `src/components/`
2. Add JSDoc header comment
3. Define prop types with interface
4. Implement component (max 400 lines)
5. Add default export
6. Update `src/components/index.ts`
7. Write tests
8. Update documentation

### Adding a New Screen

1. Create file in `src/screens/`
2. Follow component guidelines
3. Connect to stores if needed
4. Add navigation types
5. Update navigation stack
6. Write tests
7. Update documentation

### Adding a New Service

1. Create file in `src/services/`
2. Add JSDoc header comment
3. Define service class/functions
4. Handle errors appropriately
5. Add type definitions
6. Export singleton if applicable
7. Write unit tests
8. Update documentation

## Questions?

- Open an issue for clarification
- Join our Discord community
- Email: developers@runic.app

Thank you for contributing!
