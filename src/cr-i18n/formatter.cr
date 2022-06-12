module CrI18n
  abstract class Formatter(T)
    abstract def format(format : String, value : T) : String
  end

  class FormatterManager
    macro finished
    {% begin %}
      {% for f in Formatter.subclasses %}
        {% raise "Type #{f} needs to define the constant TYPE as a string representing the name of the parameter it formats for" unless f.constant("TYPE") %}
        @@{{f.id.underscore}} : {{f}} = {{f}}.new
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
        when {{f.constant("TYPE")}} then @@{{f.id.underscore}}.format(format, value)
        {% end %}
        else value
        end
        {% end %}
      end
      {% end %}
    {% end %}
    end

    # For formatter parameters that don't actually have a formatter
    def self.format(type, format, value)
      # TODO: add check to label checker that all formatted params have a formatter too
      value
    end
  end
end
