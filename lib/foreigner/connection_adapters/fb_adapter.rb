module Foreigner
  module ConnectionAdapters
    module FbAdapter
      include Foreigner::ConnectionAdapters::Sql2003

      def foreign_keys(table_name)
        fk_info = select_all %{
          SELECT
            detail_relation_constraints.rdb$constraint_name AS foreign_key_name,
            detail_index_segments.rdb$field_name            AS field_name,
            master_relation_constraints.rdb$relation_name   AS referenced_table,
            master_index_segments.rdb$field_name            AS referenced_field,
            rdb$ref_constraints.rdb$update_rule             AS update_rule,
            rdb$ref_constraints.rdb$delete_rule             AS delete_rule
          FROM
            rdb$relation_constraints detail_relation_constraints
            JOIN rdb$index_segments detail_index_segments ON
              detail_relation_constraints.rdb$index_name = detail_index_segments.rdb$index_name
            JOIN rdb$ref_constraints ON
              detail_relation_constraints.rdb$constraint_name = rdb$ref_constraints.rdb$constraint_name
            JOIN rdb$relation_constraints master_relation_constraints ON
              rdb$ref_constraints.rdb$const_name_uq = master_relation_constraints.rdb$constraint_name
            JOIN rdb$index_segments master_index_segments ON
              master_relation_constraints.rdb$index_name = master_index_segments.rdb$index_name
          WHERE
            detail_relation_constraints.rdb$constraint_type = 'FOREIGN KEY' AND
            detail_relation_constraints.rdb$relation_name = '#{ar_to_fb_case(table_name)}'
        }

        fk_info.map do |row|
          options = { :column      => row['field_name'].downcase.strip,
                      :name        => row['foreign_key_name'].downcase.strip,
                      :primary_key => row['referenced_field'].downcase.strip }

          options[:dependent] = case row['delete_rule'].downcase.strip
            when 'cascade'  then :delete
            when 'set null' then :nullify
            when 'restrict' then :restrict
          end

          ForeignKeyDefinition.new(table_name, row['referenced_table'].downcase.strip, options)
        end
      end

      def indexes(table_name, name = nil)
        old_indexes(table_name, name).select { |idx| not foreign_keys(table_name).any? { |fk| fk.options[:name] == idx.name } }
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::FbAdapter.class_eval do
  alias_method :old_indexes, :indexes
  include Foreigner::ConnectionAdapters::FbAdapter
end
