# Java Standards

## Primary Language

Java is the primary and preferred language for this project. All new features, classes, and modules must be written in Java unless a specific library requires Kotlin (e.g., Kotlin DSL build scripts).

---

## Java Code Standards

### Naming
- Classes: `PascalCase` — `UserRepository`, `TransactionAdapter`
- Methods and fields: `camelCase` — `getAccessToken()`, `syncState`
- Constants: `UPPER_SNAKE_CASE` — `MAX_RETRY_COUNT`, `DB_NAME`
- Packages: `lowercase.dotted` — `com.example.data.repository`

### Immutability
- Use `final` on all fields that are not reassigned after construction.
- Use `final` on method parameters where mutation would be a bug.
- Domain model fields should be `final` and set via constructor.

```java
// ✅ Immutable domain model
public class User {
    public final String id;
    public final String name;
    public final String email;

    public User(String id, String name, String email) {
        this.id = id;
        this.name = name;
        this.email = email;
    }
}
```

### Null Safety
- Annotate all method parameters and return types with `@NonNull` or `@Nullable`.
- Never return `null` where a `Result<T>` or `Optional<T>` would be clearer.
- Use `Objects.requireNonNull()` at constructor boundaries for mandatory arguments.

```java
// ✅ Explicit nullability contract
public class UserRemoteDataSource {

    @NonNull
    public UserResponse fetchUser(@NonNull String userId) throws AppException {
        // ...
    }
}
```

---

## Kotlin Interop

When consuming Kotlin libraries or calling Kotlin code from Java:

- Be aware that Kotlin `suspend` functions are exposed to Java as functions taking a `Continuation` parameter — use the `ListenableFuture` adapter or wrap in a Java-callable helper where needed.
- Kotlin `Flow` is not directly consumable from Java — wrap in `LiveData` at the boundary using `LiveDataReactiveStreams` or a bridge helper.
- Kotlin `data class` types are usable from Java — `equals()`, `hashCode()`, and `copy()` work as expected.

## Keep Consistency per Module

Do not mix Java and Kotlin in the same module without a clear reason. Consistency within a module is more valuable than using Kotlin in one file and Java in another.

## Avoid

- Using Kotlin-only APIs (extension functions, `let`, `apply`, `run`, `also`) in Java code.
- Calling `suspend` functions directly from Java without a proper wrapper.
- Using Kotlin coroutines from Java — use `AppExecutors` and `LiveData` instead.
