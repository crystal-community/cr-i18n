module CrI18n
  abstract class Formatter
    abstract def type : String
    abstract def format(format, value) : String

    FORMATTERS = {} of String => Formatter

    def self.init
      {% for f in Formatter.subclasses %}
    %formatter = {{f}}.new
    FORMATTERS[%formatter.type] = %formatter
    {% end %}
    end

    def self.format(type, format, value)
      # TODO: add check to label checker that all formatted params have a formatter too
      FORMATTERS[type]?.try(&.format(format, value)) || value
    end
  end
end
