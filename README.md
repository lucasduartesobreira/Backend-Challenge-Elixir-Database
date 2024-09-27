# Recursive Transactional Key-Value Database in Elixir

This project implements a **key-value database** with **recursive transactions** using Elixir. The database allows for storing, retrieving, and modifying values associated with keys. Additionally, it supports nested transactions where all operations performed in a transaction can be either committed or rolled back.

This implementation also includes **persistence** for the database, ensuring that any values stored at transaction level 0 are saved to disk, even after the program is closed. When you reopen the program, the database will load the previously persisted state.

## Challenge Overview

The main challenge was to build a simple key-value database with the following features:
1. **Basic Operations**: Storing (`SET`), retrieving (`GET`), and updating key-value pairs.
2. **Transactions**: The ability to start a transaction (`BEGIN`), roll back (`ROLLBACK`), or commit (`COMMIT`) changes.
3. **Recursive Transactions**: Transactions within transactions, where the outcome of inner transactions is applied to outer transactions.
4. **Interactive CLI**: The application runs in an interactive command-line interface (CLI) without arguments.

### Key Commands
- **SET \<key\> \<value\>**: Stores a value under a key.
- **GET \<key\>**: Retrieves the value of a key.
- **BEGIN**: Starts a new transaction.
- **ROLLBACK**: Reverts the changes of the current transaction.
- **COMMIT**: Commits the changes made during the transaction.

### Restrictions
- Must be written in **Elixir** using only its **standard library**.
- External libraries are allowed only for testing.
- The database does **not** need to be persistent, though implementing persistence is considered a bonus.
- A binary executable should be generated using `mix escript.build`.
- The CLI should ignore any command-line arguments.

## Running the Project

To run the project, first ensure you have Elixir installed. Then, use the following steps:

1. **Compile the Project**:
   ```bash
   mix escript.build
   ```
2. Run the Interactive CLI:
   ```bash
   ./desafio_cli
   ```
3. Use Commands
   ```bash
    > GET teste
    NIL
    > BEGIN
    1
    > SET teste 1
    FALSE 1
    > GET teste
    1
    > BEGIN
    2
    > SET foo bar
    FALSE bar
    > SET bar baz
    FALSE baz
    > GET foo
    bar
    > GET bar
    baz
    > ROLLBACK
    1
    > GET foo
    NIL
    > GET bar
    NIL
    > GET teste
   ```
