require 'tempfile'
require 'forwardable'
require 'logger'

class SeaPool

  Config = Struct.new(:logger, :inputs, :includes, :system_includes, :excludes, :output)

  def initialize(**opts)

    @logger = opts[:logger]||Logger.new(IO::NULL)

    @inputs = []
    @includes = []
    @system_includes = []
    @excludes = []
    @output = nil

    yield(self) if block_given?

  end

  # append file to input file list
  def add_input(*file_name)
    file_name.each { |f| @inputs.push(f) }
    self
  end

  # append path to search path
  def add_include(*file_path)
    file_path.each { |path| @includes.push(path) }
    self
  end

  # append path to system search path
  def add_system_include(*file_path)
    file_path.each { |path| @system_includes.push(path) }
    self
  end

  # append file to exlude file list
  def add_exclude(*file_name)
    file_name.each { |f| @excludes.push(f) }
    self
  end

  # set an output file
  def set_output(file_name)
    @output = file_name
    self
  end

  # combine inputs to produce output
  def run

    if @output
      output_stream = File.open(@output, "w")
    else
      output_stream = Tempfile.new
    end

    begin

      Generator.new(
        Config.new(
          @logger,
          @inputs,
          @includes,
          @system_includes,
          @excludes,
          output_stream
        )
      )

      output_stream.close
      output_stream.unlink unless @output

    rescue => e

      @logger.error e.to_s

      output_stream.close
      output_stream.unlink unless @output

      raise e

    end

    self

  end

  class Generator

    MACRO_PATTERN = /(?<macro>[_a-zA-Z][_0-9a-zA-Z]*)/
    ANGLE_PATTERN = /<(?<angle>[^>]+)>.*/
    QUOTE_PATTERN = /\"(?<quote>[^\"]+)\".*/
    INCLUDE_PATTERN = /[ \t]*#[ \t]*include[ \t]+(#{QUOTE_PATTERN}|#{ANGLE_PATTERN}|#{MACRO_PATTERN})[ t]*/

    #MACRO_FUNCTION_PATTERN = /(?<macro>[_a-zA-Z][_0-9a-zA-Z]*)/

    #DEFINE_SYMBOL_PATTERN = /[ \t]*#[ \t]*define[ \t]+#{MACRO_PATTERN}[ \t]+(.*)$/
    #DEFINE_FUNCTION_PATTERN = /[ \t]*#[ \t]*define[ \t]+#{MACRO_PATTERN}\([[_a-zA-Z]]\)(.*)$/

    class StackFrame < Struct.new(:file, :path, :input, :iter, :line_number)

      def next
        line = self.iter.next
        self.line_number = line_number.next
        line
      end

    end

    Path = Struct.new(:value, :expanded)

    extend Forwardable

    def_delegators :@config,
      :inputs,
      :excludes,
      :output,
      :logger

    attr_reader :search_path
    attr_reader :system_search_path
    attr_reader :expanded
    attr_reader :system_expanded

    def is_expanded?(f)
      not(expanded[File.expand_path(f)].nil? and system_expanded[File.expand_path(f)].nil?)
    end

    def initialize(config)

      @config = config

      @output_lines = 0
      @stack = []

      @expanded = {}
      @system_expanded = {}
      @symbols = {}

      @search_path = @config.includes.map{ |p| Path.new(p, File.expand_path(p)) }
      @system_search_path = @config.system_includes.map{ |p| Path.new(p, File.expand_path(p)) }

      inputs.each do |input_file|

        logger.debug{"processing '#{input_file}'..."}

        # exclude inputs
        if is_excluded?(input_file)

          logger.debug{"'#{input_file}' is exluded"}
          next

        end

        # don't expand twice
        next if is_expanded?(input_file)

        push(input_file)

        until empty?

          begin

            line = top.next

          rescue StopIteration

            pop
            put_line("#line #{top.line_number.next} #{top.file}") if top
            next

          end

          # we need UTF8
          unless line.valid_encoding?

            msg = "#{top.file}: #{top.line_number}: invalid encoding (passing through)"
            logger.error{msg}
            put_line(line)
            next

          end

          m = line.match(INCLUDE_PATTERN)

          if m.nil?

            #m = line.match(DEFINE_PATTERN)

            put_line(line)

          elsif m[:quote]

            expand_line(Search.new(search_path, expanded), m[:quote], line)

          elsif m[:angle]

            expand_line(Search.new(system_search_path, system_expanded, :system), m[:angle], line)

          else

            put_line(line)

          end

        end

      end

    end

    def expand_line(ctx, file, line)

      resolved = ctx.resolve(file)

      if resolved.nil?

        logger.error{"#{top.file}: #{top.line_number}: cannot resolve #{ctx.format_include(file)}"}
        put_line(line)

      elsif at = ctx.expanded_at(resolved)

        logger.debug{"#{top.file}: #{top.line_number}: #{ctx.format_include(file)} already expanded at line #{at}"}

        put_line("/* #{line.strip} first included at line #{at} */\n")

      elsif is_excluded?(resolved)

        logger.error{"#{top.file}: #{top.line_number}: exluding #{ctx.format_include(file)}"}

        put_line(line)

      else

        logger.debug{"#{top.file}: #{top.line_number}: expanding #{ctx.format_include(file)}..."}

        ctx.add_to_expanded(resolved, current_line_number+1)

        put_line("/* #{line.strip} */\n")

        put_line("#line #{1} #{file}\n") # fixme

        push(resolved)

      end

    end

    class Search

      def initialize(search_path, expanded_list, type=:local)
        @search_path = search_path
        @expanded_list = expanded_list
        @type = type
      end

      def resolve(f)
        @search_path.map{|sp|File.join(sp.expanded, f)}.detect{|actual_file|File.exist?(actual_file)}
      end

      def expanded_at(f)
        @expanded_list[f]
      end

      def add_to_expanded(f, line_number)
        @expanded_list[f] = line_number
        self
      end

      def format_include(f)
        (@type == :system) ? "<#{f}>" : "\"#{f}\""
      end

    end

    def push(f)
      expanded = File.expand_path(f)
      s = File.open(expanded, "r")
      @stack.push(StackFrame.new(f, expanded, s, s.each_line, 1))
    end

    def pop
      @stack.pop
    end

    def empty?
      @stack.empty?
    end

    def top
      @stack.last
    end

    def is_excluded?(f)
      excludes.any? {|e| e == e }
    end

    def current_line_number
      @output_lines
    end

    def put_line(line)
      output.write(line)
      @output_lines = @output_lines.next
      self
    end

  end

end





