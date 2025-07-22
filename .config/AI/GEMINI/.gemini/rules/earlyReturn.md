---
description: Enforce the use of early return to improve code readability and reduce nesting.
alwaysApply: true
---

# Rule: Prefer Early Return

## Goal

Encourage the use of **early return** in functions across all supported languages (e.g. TypeScript, Go) to:

* Improve code readability
* Minimize nesting
* Make edge-case handling explicit

Early returns help make your code easier to read and reason about by reducing unnecessary indentation and clearly separating error or exit conditions from the main logic.

## ✅ Good (Early Return)

### TypeScript

```ts
function getUserById(id: number): User | null {
  const user = getUserFromDatabase(id);
  if (!user) {
    return null;
  }
  return user;
}
```

### Go

```go
func getUserById(id int) (*User, error) {
  user, err := getUserFromDatabase(id)
  if err != nil {
    return nil, err
  }
  if user == nil {
    return nil, errors.New("user not found")
  }
  return user, nil
}
```

## 🚫 Bad (Nested Logic)

### TypeScript

```ts
function getUserById(id: number): User | null {
  const user = getUserFromDatabase(id);
  if (user) {
    return user;
  } else {
    return null;
  }
}
```

### Go

```go
func getUserById(id int) (*User, error) {
  user, err := getUserFromDatabase(id)
  if err != nil {
    return nil, err
  } else {
    if user == nil {
      return nil, errors.New("user not found")
    } else {
      return user, nil
    }
  }
}
```

