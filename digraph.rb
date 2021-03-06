=begin rdoc

A small lib for generating GraphViz dot digraphs from ruby.

=end
module Digraph
  GRAPH_DIR = '/tmp'
  
  class Node
    attr_reader :attributes
    def initialize(name, graph)
      @name, @graph = name, graph
    end
    def >>(other_node)
      @graph.add_edge(self, other_node)
      other_node
    end
    def to_s; @name end
    def [](atts); @attributes = atts; self end
    def inspect
      out = "#{@name}"
      out += " [#{@attributes}]" if @attributes
      out
    end
  end
  
  class Edge
    def initialize(from, to, atts=nil)
      @from = from
      if to.is_a?(Grapher::E)
        @to = to.node
        @attributes = to.attributes
      else
        @to = to
        @attributes = atts
      end
    end
    
    def inspect
      out = "#{@from} -> #{@to}"
      out += " [#{@attributes}]" if @attributes
      out
    end
  end
  
  class Graph
    attr_reader :name
    
    def initialize(name=nil, globals={})
      @name = name
      @globals = globals
      @nodes = {}
      @edges = []
      @attributes = {}
      @subgraphs = []
    end
    
    def add_node(name)
      node = @nodes[name]
      unless node
        node = Node.new(name, self)
        @nodes[name] = node
      end
      node
    end
    
    def add_edge(from, to, atts=nil)
      edge = Edge.new(from,to,atts)
      @edges << edge
      edge
    end
    
    def add_attribute(att, val); @attributes[att] = val end
    def add_subgraph(graph); @subgraphs << graph end
    
    def to_dot(sub=false)
      out = sub ? "subgraph #{name} {\n" : "digraph G {\n"
      @subgraphs.each {|g| out << "\n" + g.to_dot(true) }
      @globals.each {|k,v| out << "  #{k} [#{v}]\n"}
      @attributes.each {|k,v| out << "  #{k} =\"#{v}\";\n"}
      @nodes.values.each do |n|
        out << "  #{n.inspect};\n"
      end
      @edges.each {|e| out << "  #{e.inspect};\n"}
      out << "}\n"
      out
    end
    
    def write(format='png', target="graph")
      dot_file = File.join(GRAPH_DIR, "#{target}.dot")
      target_file = File.join(GRAPH_DIR, target+".#{format}")
      File.open(dot_file, 'w') {|f| f << self.to_dot}
      system("dot -T#{format} -o #{target_file} #{dot_file}")
      target_file
    end
    
  end
  
  class Grapher
    class E
      attr_reader :node, :attributes
      def initialize(node, atts)
        @node, @attributes = node, atts
      end
      def >>(other); @node >> other end
    end

    attr_reader :graph
    
    def initialize(globals={}, graph_name=nil)
      @graph = Graph.new(graph_name, globals)
    end
    
    def E(node, atts); E.new(node, atts) end
    
    def subgraph(name, globals={}, &blk)
      subgrapher = Grapher.new(globals, name)
      subgrapher.instance_eval(&blk) if block_given?
      subgrapher.transfer_attributes
      @graph.add_subgraph subgrapher.graph
    end
    
    def transfer_attributes
      (instance_variables - ["@graph"]).each do |v|
        @graph.add_attribute(v[1..-1], instance_eval(v))
      end
    end
    
    private
    def method_missing(meth, *args)
      if args.empty?
        @graph.add_node(meth.to_s)
      else
        super
      end
    end
  end
  
  def self.new(globals={}, &blk)
    grapher = Grapher.new(globals)
    grapher.instance_eval(&blk) if block_given?
    grapher.transfer_attributes
    grapher.graph
  end
end
