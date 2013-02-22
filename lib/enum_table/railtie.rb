module EnumTable
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :enum_table do
        task :load_schema_dumper do
          require 'enum_table/schema_dumper'
        end

        task :allow_missing_tables do
          EnumTable.missing_tables_allowed
        end
      end

      Rake::Task['db:schema:dump'].prerequisites << 'enum_table:load_schema_dumper'

      %w'db:schema:load db:migrate db:migrate:up'.each do |task|
        task = Rake::Task[task]
        task.prerequisites.insert 0, 'enum_table:allow_missing_tables'
        task.enhance { EnumTable.missing_tables_disallowed }
      end
    end
  end
end
