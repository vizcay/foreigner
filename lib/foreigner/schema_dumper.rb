module Foreigner
  module SchemaDumper
    extend ActiveSupport::Concern

    included do
      def foreign_keys(table_name, stream)
        puts table_name
        if (foreign_keys = @connection.foreign_keys(table_name)).any?
          add_foreign_key_statements = foreign_keys.map do |foreign_key|
            '  ' + self.class.dump_foreign_key(foreign_key)
          end

          stream.puts add_foreign_key_statements.sort.join("\n")
          stream.puts
        end
      end
    end

    module ClassMethods
      def dump_foreign_key(foreign_key)
        statement_parts = [ ('add_foreign_key ' + remove_prefix_and_suffix(foreign_key.from_table).inspect) ]
        statement_parts << remove_prefix_and_suffix(foreign_key.to_table).inspect
        statement_parts << (':name => ' + foreign_key.options[:name].inspect)

        if foreign_key.options[:column] != "#{remove_prefix_and_suffix(foreign_key.to_table).singularize}_id"
          statement_parts << (':column => ' + foreign_key.options[:column].inspect)
        end
        if foreign_key.options[:primary_key] != 'id'
          statement_parts << (':primary_key => ' + foreign_key.options[:primary_key].inspect)
        end
        if foreign_key.options[:dependent].present?
          statement_parts << (':dependent => ' + foreign_key.options[:dependent].inspect)
        end

        statement_parts.join(', ')
      end

      def remove_prefix_and_suffix(table)
        table.gsub(/^(#{ActiveRecord::Base.table_name_prefix})(.+)(#{ActiveRecord::Base.table_name_suffix})$/,  "\\2")
      end
    end
  end
end
