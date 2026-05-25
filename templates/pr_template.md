# Pull Request

## Summary

<!-- What does this PR do and why? 2–3 sentences.
     Focus on the business reason, not the file list.
     Example: "Adds partial payment support to the credit tracking feature.
     Business owners can now record repayments in any amount and see a
     running balance per customer, reducing disputes over outstanding debt." -->

---

## Changes

<!-- List the layers affected and what changed in each.
     Be specific — name the classes, not just the folders.

     Example:
     - domain/usecase: PartialPaymentUseCase — applies repayment, returns updated balance
     - domain/model: CreditRecord — added repayments: List<Repayment> field
     - data/repository: CreditRepositoryImpl — persists repayments, recomputes balance
     - data/datasource/local: CreditDao — added insertRepayment() and getRepayments()
     - ui/screen: CreditDetailScreen — displays running balance and payment history
     - di/module: RepositoryModule — binds CreditRepository to CreditRepositoryImpl -->

---

## Risks

<!-- What could break? What assumptions does this change make?
     Flag anything that touches shared state, migrations, or auth.
     If none, write "None identified."

     Example:
     - CreditRecord schema change requires migration. Migration 3→4 is included.
     - PartialPaymentUseCase assumes balance never goes negative — no guard added yet. -->

---

## Testing

<!-- How was this tested? List test method names or describe manual steps.
     At minimum, cover the happy path and the primary failure case.

     Example:
     - givenValidRepayment_whenRecording_thenBalanceDecreases ✓
     - givenRepaymentExceedsBalance_whenRecording_thenErrorReturned ✓
     - givenNoRepayments_whenViewingCredit_thenFullBalanceShown ✓
     - Manual: recorded three partial payments, verified running total matches expected -->
