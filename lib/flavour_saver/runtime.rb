require 'cgi'

module FlavourSaver
  UnknownNodeTypeException = Class.new(StandardError)
  UnknownContextException  = Class.new(StandardError)
  class Runtime

    attr_accessor :context

    def self.run(ast, context) 
      self.new(ast,context).to_s
    end

    def initialize(ast, context=nil, parent=nil)
      @ast = ast
      @context = context
      @parent = parent
    end

    def to_s
      evaluate_node(@ast)
    end

    def evaluate_node(node,block=[])
      case node
      when TemplateNode
        result = ''
        pos = 0
        len = node.items.size
        while(pos < len)
          n = node.items[pos]
          if n.is_a? BlockStartExpressionNode
            blocknode = n
            blockbody = []
            pos += 1
            while (blockbody.last != blocknode.closed_by)
              n = node.items[pos]
              blockbody << n
              pos += 1
            end
            result << evaluate_block(blocknode, blockbody).to_s
          else
            result << evaluate_node(n).to_s
            pos += 1
          end
        end
        result
      when OutputNode
        node.value
      when StringNode
        node.value
      when SafeExpressionNode
        evaluate_expression(node).to_s
      when ExpressionNode
        CGI.escapeHTML(evaluate_expression(node).to_s)
      when CallNode
        evaluate_call(node)
      when Hash
        node.each do |key,value|
          node[key] = evaluate_argument(value)
        end
        node
      when CommentNode
        ''
      else
        raise UnknownNodeTypeException, "Don't know how to deal with a node of type #{node.class.to_s.inspect}."
      end
    end

    def parent
      raise UnknownContextException, "No parent context in which to evaluate the parentiness of the context"
    end

    def evaluate_call(call, context=@context, &block)
      case call
      when ParentCallNode
        parent.evaluate_call(call,context,&block)
      when LiteralCallNode
        context.send(:[], call.name, &block)
      else
        context.send(call.name, *call.arguments.map { |a| evaluate_argument(a) }, &block)
      end
    end

    def evaluate_argument(arg)
      if arg.is_a? Array
        arg.map{ |a| evaluate_node(a) }.join ''
      else
        evaluate_node(arg)
      end
    end

    def evaluate_expression(node, &block)
      node.method.inject(@context) do |result,call|
        result = evaluate_call(call, result, &block)
      end
    end

    def evaluate_block(node,body=[])
      child = create_child_runtime(body)
      block = proc do |context|
        child.context = context
        result = child.to_s
        child.context = nil
        result
      end
      evaluate_call(node.method.first, context, &block)
    end

    def create_child_runtime(body=[])
      Runtime.new(TemplateNode.new(body),nil,self)
    end

  end
end