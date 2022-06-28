module CrI18n
  abstract class Formatter(T)
    abstract def format(format : String, value : T) : String
  end

  class FormatterManager
    macro finished
      macro finished
      {% begin %}
        {% for f in Formatter.subclasses %}
          {% raise "Type #{f} needs to define the constant TYPE as a string representing the name of the parameter it formats for" unless f.constant("TYPE") %}
          @@{{"#{f}".gsub(/::/, "__").id.underscore}} : {{f}} = {{f}}.new
        {% end %}

        {% types_formatters = {} of Nil => Nil %}
        {% for f in Formatter.subclasses %}
        {% types_formatters[f.ancestors[0].type_vars[0].id] = (types_formatters[f.constant("TYPE")] || [] of Nil) + [f] %}
        {% end %}

        # Break up the list of formatters by their type, let the compiler handle the type inference and calling the correct format method
        {% for type, formatters in types_formatters %}
        def self.format(type, format, value : {{type}})
          {% begin %}
          case type
          {% for f in formatters %}
          when {{f.constant("TYPE")}} then @@{{"#{f}".gsub(/::/, "__").id.underscore}}.format(format, value)
          {% end %}
          else value
          end
          {% end %}
        end
        {% end %}
      {% end %}
      end

      {% begin %}
        FORMATTER_EXPECTED_TYPE = {
          {% for f in Formatter.subclasses %}
          {{f.constant("TYPE")}} => "{{f.ancestors[0].type_vars[0].id}}",
          {% end %}
        } of String => String
      {% end %}

      # For formatter parameters that don't actually have a formatter
      def self.format(type, format, value)
        raise "For formatter for type '#{type}', expected value to be a #{FORMATTER_EXPECTED_TYPE[type]?}, but received a #{value.class} instead" if FORMATTER_EXPECTED_TYPE[type]? && FORMATTER_EXPECTED_TYPE[type] == value.class.to_s
        value
      end
    end
  end
end
