## Enum Table

Table-based enumerations for ActiveRecord.

## What?

When you have a column that should only take one of a finite set of string
values (e.g., gender, statuses through some workflow), it's usually best not to
store these as strings. Many databases, such as MySQL and PostgreSQL have native
enum types which effectively let you treat these as strings while storing them
internally using as few bytes as possible. Indeed there are already
[plugins][enum_column3] that let you use these native enum types.

But sometimes this is inadequate.

Most obviously, not all databases have a native enum type, notably SQLite.

Further, in the case of MySQL, the enum type leaves a lot to be desired in a
production setting. If you need to do anything to the list of allowed values
other than adding values to the end of the list, MySQL will rebuild the entire
table, which can be very slow. Unless you're using something like
[pt-online-schema-change][pt-osc], it will also lock the table during this
period, which could be unacceptable for large tables.

A common alternative is to simply keep the value-to-id mapping in the
application, hardcoded in the model. The downside of this is that your database
is no longer self-documenting: the integers mean nothing without the value
mapping buried in your application code, making it hard to work with the
database directly. Another problem is the database cannot enforce any
[referential integrity][foreigner].

This plugin implements a different strategy which solves the above problems -
each enum is defined by a table with `id` and `value` columns, which defines the
values and the integers they map to. Altering the values can be done with simple
DDL statements, which do not require rebuilding any tables.

[enum_column3]: https://github.com/taktsoft/enum_column3
[pt-osc]: http://www.percona.com/doc/percona-toolkit/2.1/pt-online-schema-change.html
[foreigner]: https://github.com/matthuhiggins/foreigner

## Usage

Create your enum tables in migrations. Example:

    create_enum_table :user_genders do |t|
      t.add :male
      t.add :female
    end

Then add the enum ID to your model table:

    add_column :users, :gender_id, null: false

Then in your model:

    class User < ActiveRecord::Base
      enum :gender
    end

Note the convention: for a model `User` with enum `gender`, the column is
`users.gender_id`, and the enum_table is `user_genders`. You can override these
with the `:id_name` and `:table` options:

    enum :gender, id_name: :sex_id, table: :sexes

### Custom columns

While the names `id` and `value` are fixed, you can change other attributes of
the column. For example, the ID has `limit: 1` by default, but you can change
this if you have a large list of enum values:

    create_enum_table :user_countries do |t|
      t.id limit: 2
      t.add 'Afghanistan'
      t.add 'Albania'
      # ...
    end

Similarly you can customize the `value` column, say if you want to place a
varchar limit:

    create_enum_table :user_countries do |t|
      t.value limit: 100
      # ...
    end

### Updating enums

To change the list of enums:

    change_enum_table :user_genders do |t|
      t.add :other
      t.remove :male
    end

To drop an enum table:

    drop_enum_table :user_genders

Under the hood, `create_enum_table` and `drop_enum_table` maintain the list of
enum tables in the `enum_tables` table. This allows the table data to be tracked
by `db/schema.rb` so it gets copied to your test database.

### Hardcoded mappings

If you really want, you can forego the table completely and just hardcode the
ids and values in your model:

    enum :genders, table: {male: 1, female: 2}

Or since our IDs are 1-based and sequential:

    enum :genders, table: [:male, :female]

Of course, by not using tables, you lose some of the advantages mentioned
earlier, namely a self-documenting database and referential integrity.

### Values

By default, `user.gender` will be either the symbol `:male` or `:female`. If
you're transitioning from using old-fashioned `varchar`s, however, you may find
it less disruptive to use strings instead. Do that with the `:type` option:

    enum :genders, type: :string

## Contributing

 * [Bug reports](https://github.com/howaboutwe/enum_table/issues)
 * [Source](https://github.com/howaboutwe/enum_table)
 * Patches: Fork on Github, send pull request.
   * Include tests where practical.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) HowAboutWe. See LICENSE for details.
