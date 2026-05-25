# Database Guidelines

Room + SQLCipher implementation rules. The offline-first contract (Room as source of truth, sync via WorkManager) is defined in `architecture_standard.md` §10. See also `examples/offline_first_repository.md` for the full pattern.

---

## Encryption — mandatory

All Room databases must be encrypted with SQLCipher. An unencrypted database in production is a security violation.

```java
// ✅ Correct setup in DatabaseModule
@Provides
@Singleton
public AppDatabase provideDatabase(
        @ApplicationContext Context context,
        KeystoreHelper keystoreHelper) {

    byte[] passphrase = keystoreHelper.getDatabasePassphrase();
    SupportFactory factory = new SupportFactory(passphrase);

    return Room.databaseBuilder(context, AppDatabase.class, "app.db")
        .openHelperFactory(factory)
        .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
        // ❌ Never: .fallbackToDestructiveMigration()
        .build();
}
```

**Rules:**
- Passphrase from Android Keystore only — never hardcoded.
- `fallbackToDestructiveMigration()` is **forbidden** — it silently deletes all user data.

---

## DAO Rules

```java
@Dao
public interface TransactionDao {

    // ✅ LiveData for reads — Room delivers updates on a background thread automatically
    @Query("SELECT id, amount, type, date, sync_state FROM transactions WHERE date = :date ORDER BY created_at DESC")
    LiveData<List<TransactionEntity>> getByDate(String date);

    // ✅ void for writes — must be called from AppExecutors.diskIO()
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void upsertAll(List<TransactionEntity> entities);

    @Query("DELETE FROM transactions WHERE id = :id")
    void deleteById(String id);

    // ✅ @Transaction for multi-table queries
    @Transaction
    @Query("SELECT * FROM transactions WHERE date = :date")
    LiveData<List<TransactionWithCredit>> getTransactionsWithCredit(String date);
}
```

**Rules:**
- All reads return `LiveData<T>` — they auto-update when the underlying table changes. Room handles threading for LiveData returns automatically.
- All writes are `void` (or return `long`/`int` for insert/update counts) and **must be called from a background thread** via `AppExecutors.diskIO()`.
- Use `@Insert(onConflict = OnConflictStrategy.REPLACE)` for idempotent insert-or-update — avoids duplication on re-sync. (Room 2.5+ also provides `@Upsert` which is preferred when available.)
- Use `@Transaction` on any query that touches multiple tables or performs multiple writes.
- Never use `SELECT *` — always name columns explicitly to avoid breaking changes when schema evolves.

---

## Entity Design

```java
@Entity(
    tableName = "transactions",
    indices = {
        @Index(value = {"date"}),                          // ✅ Indexed — queried frequently
        @Index(value = {"sync_state"}),                    // ✅ Indexed — filtered on sync
        @Index(value = {"reference"}, unique = true)       // ✅ Unique — prevents duplicate imports
    }
)
public class TransactionEntity {

    @PrimaryKey
    @NonNull
    public String id;           // ✅ String UUID — safe for offline creation

    public long amount;         // ✅ long (minor units) — never double/float for money

    @NonNull
    public String currencyCode; // ✅ ISO 4217 — multi-currency from day one

    @NonNull
    public String type;

    @NonNull
    public String date;         // ISO 8601 string — LocalDate requires TypeConverter

    @NonNull
    public String syncState = SyncState.PENDING.name(); // ✅ Track sync from day one

    public long createdAt;      // Unix epoch millis
    public long updatedAt;      // ✅ For conflict resolution (remote wins on updatedAt)
}
```

**Rules:**
- Use `String` UUID primary keys — auto-increment integers break offline record creation.
- Store monetary amounts as `long` in minor units (e.g., cents) — never `double` or `float`.
- Include `currencyCode` on every monetary entity — multi-currency support cannot be retrofitted.
- Include `syncState`, `createdAt`, and `updatedAt` on all syncable entities from the first migration.
- Index columns that appear in `WHERE`, `ORDER BY`, or `JOIN` clauses.
- Use `@NonNull` on all fields that must not be null — Room enforces this at compile time.

---

## Type Converters

Room does not natively support `java.time` types. Add TypeConverters for custom types.

```java
// data/model/Converters.java
public class Converters {

    @TypeConverter
    public static String fromLocalDate(LocalDate date) {
        return date != null ? date.toString() : null;
    }

    @TypeConverter
    public static LocalDate toLocalDate(String dateString) {
        return dateString != null ? LocalDate.parse(dateString) : null;
    }

    @TypeConverter
    public static Long fromInstant(Instant instant) {
        return instant != null ? instant.toEpochMilli() : null;
    }

    @TypeConverter
    public static Instant toInstant(Long millis) {
        return millis != null ? Instant.ofEpochMilli(millis) : null;
    }
}

// Register on the database class
@Database(entities = {TransactionEntity.class}, version = 1)
@TypeConverters({Converters.class})
public abstract class AppDatabase extends RoomDatabase { ... }
```

---

## Migrations — no exceptions

Every schema change requires an explicit migration. No automatic schema drops in production.

```java
// data/datasource/local/Migrations.java
public class Migrations {

    public static final Migration MIGRATION_1_2 = new Migration(1, 2) {
        @Override
        public void migrate(@NonNull SupportSQLiteDatabase db) {
            // ✅ Explicit SQL — never rely on Room to infer it
            db.execSQL("ALTER TABLE transactions ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'PENDING'");
        }
    };

    public static final Migration MIGRATION_2_3 = new Migration(2, 3) {
        @Override
        public void migrate(@NonNull SupportSQLiteDatabase db) {
            db.execSQL("CREATE INDEX IF NOT EXISTS index_transactions_sync_state ON transactions(sync_state)");
        }
    };
}
```

**Rules:**
- New columns must have a `DEFAULT` value to be non-breaking on existing data.
- Test migrations with `MigrationTestHelper` — do not ship migrations only tested at runtime.
- Keep all migration objects in `Migrations.java` — do not inline them in the module.

---

## Query Performance

**Rules:**
- Never load entire tables into memory — use `LiveData<List<T>>` with a `WHERE` clause or Paging 3.
- Avoid `N+1` queries — use Room `@Relation` or an explicit `JOIN` query.
- Avoid deeply nested `@Relation` objects — they load eagerly and can be expensive.
- For large lists in the UI, use Paging 3 with a `PagingSource` backed by the DAO.

```java
// ✅ Paging source from Room
@Query("SELECT id, amount, date FROM transactions WHERE date BETWEEN :start AND :end ORDER BY date DESC")
PagingSource<Integer, TransactionEntity> getTransactionsPaged(String start, String end);
```

---

## Soft Deletes for Syncable Data

```java
// ✅ Soft delete — record survives for server reconciliation
@Query("UPDATE transactions SET is_deleted = 1, updated_at = :now WHERE id = :id")
void markDeleted(String id, long now);

// Hard delete only after server confirms deletion
@Query("DELETE FROM transactions WHERE id = :id AND is_deleted = 1")
void hardDelete(String id);
```

**Rules:**
- Records that sync with a server must use soft deletes — hard-deleting before server confirmation causes ghost records.
- Include `isDeleted` (int, 0/1) and `updatedAt` on all syncable entities.
