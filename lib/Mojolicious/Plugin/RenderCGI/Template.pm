package Mojolicious::Plugin::RenderCGI::Template;
use Mojo::Base -base;
use CGI;

my $CGI = CGI->new ;

has [qw(_plugin _import _content)];
#~ has _cgi => sub { CGI->new };

sub new {
    my $self = shift->SUPER::new(@_);
    CGI->import(
      $self->_import && ref($self->_import) eq 'ARRAY'
        ? @{$self->_import}
        : (grep /\w/, split(/\s+/, $self->_import)),
      'escapeHTML',
      '-utf8',
    );
    return $self;
}


sub _compile {
  my $self = shift;
  my ($code) = @_;

  $self->_content(eval <<CODE);
sub {
  my (\$self, \$c, \$cgi) = \@_;
  undef, # может комменты придут без кода
  $code
}
CODE
  return $@
    if $@;
  return $self;
}

sub _run {
  my ($self, $c) = @_;
  
  $self->_content->($self, $c, $CGI);
}

sub esc { escapeHTML(@_) }

#~ our $AUTOLOAD;
sub  AUTOLOAD {
  #~ my ($func) = $AUTOLOAD =~ /([^:]+)$/;
  my ($package, $func) = our $AUTOLOAD =~ /^(.+)::(.+)$/;
  my $tag = $func =~ s/_/-/gr;
  my $package_arg = ref $_[0];
  no strict 'refs';
  no warnings 'redefine';
  
  if ($package eq $package_arg) { # method
    my $self = shift;
    if ($CGI->can($func)) {
      *{"${package}::$func"} = &_cgi_meth($func);
    } else { # HTML tag
      *{"${package}::$func"} = &_cgi_tag($tag);
    }
    return $self->$func(@_);
  }
   
  # non method
  if ($CGI->can($func)) {
    *$func = sub { $CGI->$func(@_); };
  } else {
    *$func = &_cgi_tag($tag); # sub { return &CGI::_tag_func($tag,@_); };
  }
  return &$func(@_);
  
}

sub _cgi_method {
  my $method = shift;
  return sub { my $self = shift; $CGI->$method(@_); };
}


sub _cgi_tag = sub {
  my $tag = shift;
  return sub { &CGI::_tag_func($tag,@_); };
}


1;