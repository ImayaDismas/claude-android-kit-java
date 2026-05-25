# Performance Guidelines

## General

- Minimize object allocations in hot paths (RecyclerView `onBindViewHolder`, draw callbacks).
- Use `setHasFixedSize(true)` on RecyclerView when item count changes do not affect the RecyclerView's size.
- Avoid blocking the main thread — all I/O and network work must go through `AppExecutors`.
- Use `DiffUtil` via `ListAdapter` — avoids full RecyclerView redraws on list updates.

## RecyclerView

- Use `RecyclerView.RecycledViewPool` for nested RecyclerViews sharing the same item types.
- Avoid inflating complex layouts inside `onBindViewHolder` — inflate in `onCreateViewHolder`.
- Use `ViewBinding` in ViewHolder — eliminates repeated `findViewById()` traversals.
- Avoid setting `OnClickListener` inside `onBindViewHolder` — set it once in `onCreateViewHolder` or ViewHolder constructor and capture the item reference.
- Use `payload` in `notifyItemChanged(position, payload)` for partial item updates — avoids full item rebind.

## Database

- Index frequently queried columns — `WHERE`, `ORDER BY`, `JOIN` columns must have indices.
- Never load entire tables into memory — always use `WHERE` clauses, `LIMIT`, or Paging 3.
- Avoid `N+1` queries — use `@Relation` with `@Transaction` or explicit JOIN queries.
- Room `LiveData<T>` is efficient — it only notifies observers when the underlying data changes.

## Networking

- Share a single `OkHttpClient` `@Singleton` — the connection pool is expensive to recreate.
- Enable HTTP response caching for appropriate endpoints via `OkHttpClient.cache()`.
- Use Paging 3 for paginated lists — avoids loading all pages at once.

## UI / XML

- Avoid deep view hierarchies — prefer `ConstraintLayout` over nested `LinearLayout`.
- Use `include` and `merge` tags to reuse layout components without extra parent views.
- Defer non-critical view inflation with `ViewStub`.
- Use `android:visibility="gone"` instead of `invisible` when the view is not needed — gone views are not measured.

## Memory

- Set `binding = null` in `onDestroyView()` in every Fragment — prevents leaking the view hierarchy.
- Never store `Activity` or `Fragment` references in singletons or long-lived objects.
- Use `WeakReference<Context>` only as a last resort — prefer injecting `Application` context where a long-lived context is needed.
- Recycle `Bitmap` objects explicitly when managing bitmaps manually (prefer Glide/Coil which handle this automatically).
