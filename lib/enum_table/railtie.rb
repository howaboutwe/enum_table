module EnumTable
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :enum_table do
        task :load_schema_dumper do
          require 'enum_table/schema_dumper'
        end
      end

      Rake::Task['db:schema:dump'].prerequisites << 'enum_table:load_schema_dumper'
    end
  end
end
