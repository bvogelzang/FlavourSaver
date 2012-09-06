require 'flavour_saver/parser'
require 'flavour_saver/lexer'

describe FlavourSaver::Parser do
  it 'is a RLTK::Parser' do
    subject.should be_a(RLTK::Parser)
  end

  describe 'HTML template' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('<html><h1>Hello world!</h1></html>')) }
    
    it 'is an output node' do
      subject.items.first.should be_a(FlavourSaver::OutputNode)
    end

    it 'has the correct contents' do
      subject.items.first.value.should == '<html><h1>Hello world!</h1></html>'
    end
  end

  describe 'HTML template containing a handlebars expression' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('<html>{{foo}}</html>')) }

    it 'has template output either side of the expression' do
      subject.items.map(&:class).should == [FlavourSaver::OutputNode, FlavourSaver::ExpressionNode, FlavourSaver::OutputNode]
    end
  end

  describe '{{foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo}}')) }

    it 'contains an expression node' do
      subject.items.first.should be_an(FlavourSaver::ExpressionNode)
    end

    it 'calls the method "foo" with no arguments' do
      subject.items.first.method.should be_one
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.should be_empty
    end
   end

  describe '{{foo.bar}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo.bar}}')) }

    it 'calls two methods' do
      subject.items.first.method.size.should == 2
    end

    it 'calls the method "foo" with no arguments first' do
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.should be_empty
    end

    it 'calls the method "bar" with no arguments second' do
      subject.items.first.method[1].should be_a(FlavourSaver::CallNode)
      subject.items.first.method[1].name.should == 'bar'
      subject.items.first.method[1].arguments.should be_empty
    end
  end

  describe '{{foo.[&@^$*].bar}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo.[&@^$*].bar}}')) }

    it 'calls three methods' do
      subject.items.first.method.size.should == 3
    end

    it 'calls the method "foo" with no arguments first' do
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.should be_empty
    end

    it 'calls the method "&@^$*" with no arguments second' do
      subject.items.first.method[1].should be_a(FlavourSaver::CallNode)
      subject.items.first.method[1].name.should == '&@^$*'
      subject.items.first.method[1].arguments.should be_empty
    end

    it 'calls the method "bar" with no arguments third' do
      subject.items.first.method[2].should be_a(FlavourSaver::CallNode)
      subject.items.first.method[2].name.should == 'bar'
      subject.items.first.method[2].arguments.should be_empty
    end
  end

  describe '{{foo bar}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo bar}}')) }

    it 'calls the method "foo" with a method argument of "bar"' do
      subject.items.first.method.should be_one
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.should be_one
      subject.items.first.method.first.arguments.first.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.arguments.first.first.name.should == 'bar'
    end
  end

  describe '{{foo "bar" }}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo "bar" }}')) }

    it 'calls the method "foo" with a string argument of "bar"' do
      subject.items.first.method.should be_one
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.should be_one
      subject.items.first.method.first.arguments.first.should be_a(FlavourSaver::StringNode)
      subject.items.first.method.first.arguments.first.value.should == 'bar'
    end
  end

  describe '{{foo     bar  "baz" }}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo    bar  "baz" }}')) }

    it 'calls the method "foo"' do
      subject.items.first.method.should be_one
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
    end

    describe 'with arguments' do
      subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo    bar  "baz" }}')).items.first.method.first.arguments }

      describe '[0]' do
        it 'is the method call "bar" with no arguments' do
          subject.first.first.should be_a(FlavourSaver::CallNode)
          subject.first.first.name.should == 'bar'
        end
      end

      describe '[1]' do
        it 'is the string "baz"' do
          subject[1].should be_a(FlavourSaver::StringNode)
          subject[1].value.should == 'baz'
        end
      end
    end
  end

  describe '{{foo bar="baz"}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo bar="baz"}}')) }

    it 'calls the method "foo" with the hash {:bar => "baz"} as arguments' do
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.first.should be_a(Hash)
      subject.items.first.method.first.arguments.first.should == { :bar => FlavourSaver::StringNode.new('baz') }
    end
  end

  describe '{{foo bar="baz" fred="wilma"}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo bar="baz" fred="wilma"}}')) }

    it 'calls the method "foo" with the hash {:bar => "baz", :fred => "wilma"} as arguments' do
      subject.items.first.method.first.should be_a(FlavourSaver::CallNode)
      subject.items.first.method.first.name.should == 'foo'
      subject.items.first.method.first.arguments.first.should be_a(Hash)
      subject.items.first.method.first.arguments.first.should == { :bar => FlavourSaver::StringNode.new('baz'), :fred => FlavourSaver::StringNode.new('wilma') }
    end
  end

  describe '{{foo bar="baz" fred "wilma"}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{foo bar="baz" fred "wilma"}}')) }

    it 'raises an exception' do
      -> { subject }.should raise_exception(RLTK::NotInLanguage)
    end
  end

  describe '{{{foo}}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{{foo}}}')) }

    it 'returns a safe expression node' do
      subject.items.first.should be_a(FlavourSaver::SafeExpressionNode)
    end
  end

  describe '{{../foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{../foo}}')) }

    it 'returns a parent call node' do
      subject.items.first.method.first.should be_a(FlavourSaver::ParentCallNode)
    end
  end

  describe '{{! comment}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{! comment}}')) }

    it 'returns a comment node' do
      subject.items.first.should be_a(FlavourSaver::CommentNode)
    end
  end

  describe '{{#foo}}hello{{/foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{#foo}}hello{{/foo}}')) }

    it 'has a block start and end' do
      subject.items.map(&:class).should == [ FlavourSaver::BlockStartExpressionNode, FlavourSaver::OutputNode, FlavourSaver::BlockCloseExpressionNode ]
    end

    describe FlavourSaver::BlockStartExpressionNode do
      it 'links to the closing node' do
        subject.items.first.closed_by.should == subject.items.last
      end
    end
  end

  describe '{{/foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{/foo}}')) }

    it 'raises UnbalancedBlockError for "/foo"' do
      -> { subject }.should raise_error(FlavourSaver::Parser::UnbalancedBlockError, /\/foo/)
    end
  end

  describe '{{#foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{#foo}}')) }

    it 'raises UnbalancedBlockError for "#foo"' do
      -> { subject }.should raise_error(FlavourSaver::Parser::UnbalancedBlockError, /#foo/)
    end
  end

  describe '{{#foo}}{{#bar}}{{/foo}}' do
    subject { FlavourSaver::Parser.parse(FlavourSaver::Lexer.lex('{{#foo}}{{#bar}}{{/foo}}')) }

    it 'raises UnbalancedBlockError for "#bar"' do
      -> { subject }.should raise_error(FlavourSaver::Parser::UnbalancedBlockError, /#bar/)
    end
  end

end
