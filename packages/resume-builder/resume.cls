\ProvidesClass{resume}[2022/06/04 Matt's Resume Class]
\LoadClass[11pt,letterpaper]{article}

\usepackage[parfill]{parskip}       % Do not indent paragraphs
\usepackage{array}                  % required for boldface tabular columns
\usepackage{titlesec}
\usepackage{enumitem}
\usepackage{amssymb,graphicx}
\usepackage{multicol}
\usepackage{mathabx}
\usepackage{forarray}
\usepackage[left=.4in, right=.4in, top=.7in, bottom=1.25in]{geometry}
\usepackage{xparse}
\usepackage{xifthen}
\usepackage{helvet}
\usepackage{xifthen}
\usepackage{etoolbox}
\usepackage{ragged2e}
\usepackage{fancyhdr}
\usepackage{lastpage}
\let\nofiles\relax

\renewcommand{\familydefault}{\sfdefault}

\nofiles                            % .aux files are not needed for resumes

 % Redefining headrule
\makeatletter
\fancyhf{}% Clear all headers/footers

\fancypagestyle{firstp}{
    % Definition of the header
    \renewcommand{\headrule}{\hrule height 0pt \vspace{0pt}\hrule height 0pt}
    \renewcommand{\headrulewidth}{0pt}
    \fancyhead[L]{}\fancyhead[C]{\resumeheader}\fancyhead[R]{}
    \fancyfoot[C]{$ \sqbullet $ \ \ \ $ \sqbullet $ \ \ \ $ \sqbullet  $}
    \setlength{\headsep}{0.5in}
  }
\fancypagestyle{otherp}{
    % Definition of the header
    \renewcommand{\headrule}{\hrule height 1.0pt \vspace{1pt}\hrule height 0.9pt}
    \renewcommand{\headrulewidth}{0.6pt}
    \fancyhead[L]{\bf \@name}\fancyhead[C]{\@email}\fancyhead[R]{\thepage\ of \pageref{LastPage}}
    \fancyfoot[C]{$ \sqbullet $ \ \ \ $ \sqbullet $ \ \ \ $ \sqbullet  $}
    %
 }

\pagestyle{otherp}

\setlength{\columnsep}{1pt}
\setlength{\headheight}{40pt} 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HEADINGS: Commands for printing name and address

\def \name#1{\def\@name{#1}}        % \name command can be used to set name
\def \@name {My Name}                      % Set \@name to empty by default

\def \citystate#1{\def\@citystate{#1}}
\def \@citystate {City, ST}

\def \phone#1{\def\@phone{#1}}
\def \@phone {555.867.5309}

\def \email#1{\def\@email{#1}}
\def \@email {my@email.com}

\newcommand{\resumeheader}{
  \titleformat{\section}
  {\huge\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[\vspace{0em}{\titlerule[4pt]}]
  \section{\@name}
  \vspace{-.75em}
  \titleformat{\section}
  {\center}
  {}
  {0em}
  {}[{\vspace{0ex}\titlerule[1pt]}]
  \section{\@citystate $\sqbullet$ \@phone $\sqbullet$ \@email}
}

\newcommand{\profile}[1]{
  \titleformat{\section}
  {\large\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[]
  \section{\Large{Profile}}
  #1
}

\newcommand{\education}{
  \vspace{-3em}
  \titleformat{\section}
  {\huge\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[\vspace{0em}{\titlerule[4pt]}]
  \section{}
  \vspace{-.75em}
  \titleformat{\section}
  {\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[{\vspace{0ex}\titlerule[1pt]}]
  \section{\Large{Education}}
}

\newcommand{\techskills}{
  \vspace{-3em}
  \titleformat{\section}
  {\huge\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[\vspace{0em}{\titlerule[4pt]}]
  \section{}
  \vspace{-.75em}
  \titleformat{\section}
  {\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[{\vspace{0ex}\titlerule[1pt]}]
  \section{\Large{Technical Skills}}
}

\providetoggle{firstskill}
\settoggle{firstskill}{true}

\newcommand{\skills}[1]{\newcommand{\myskills}{\ignorespaces#1}}
\newcommand{\skill}[1]{%
  \iftoggle{firstskill}{#1  }{$ \sqbullet $  #1  }%
  \settoggle{firstskill}{false}%
  \ignorespaces
}

\DeclareRobustCommand\checkfor[1]{%
  \begingroup
  \expandafter\ifx\csname#1\endcsname\relax\expandafter\@firstoftwo\else\expandafter\@secondoftwo\fi
  {%
    \expandafter\endgroup\expandafter\ifx\csname#1\endcsname\relax\expandafter\@firstoftwo\else\expandafter\@secondoftwo\fi
  }{\endgroup\@firstoftwo}%
}%

\newcommand\comp[1]{%
    \@ifnextchar\bgroup{\comp@double{#1}}{\comp@single{#1}}%
}
\newcommand\comp@single[1]{%
    {{#1}}%
}
\newcommand\comp@double[2]{%
    {#2 \backslash #1}%
}

\newcommand{\school}[4]{
    \center
    \bf #1 \normalfont -- #2 \\
    #3 #4
    % \checkfor{#4}{good}{}
}

\newcommand{\professionalexperience}{
  \vspace{-3em}
  \titleformat{\section}
  {\huge\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[\vspace{0em}{\titlerule[4pt]}]
  \section{}
  \vspace{-.75em}
  \titleformat{\section}
  {\bfseries\center}
  {}
  {0em}
  {\MakeUppercase}[{\vspace{0ex}\titlerule[1pt]}]
  \section{\Large{Professional Experience}}
  \bf
  \center \small\uppercase{Relevant Experience}
  \normalfont
}

\newlist{profilelist}{enumerate}{3}
\setlist[profilelist]{label=$\bullet$}
% \newlist{corecomps}{multicols}{3}
% \setlist{corecomps}{label=\blacksquare}

\newcommand{\job}[6]{
    \begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} l l @{}}
        \begin{tabular}[b]{@{}l}
            #1 - #2 \hfil \\
            \bf
            \small #3
            \end{tabular} 
        &
        \hfill
        \normalfont #4
    \end{tabular*}
    \hrule
    \normalfont
    \begin{justify}
    #5 \\
    \vspace{0.5em}
    \ifx#6\else\bf \vspace{-1em}\\ Key Accomplishments \\\fi
        \normalfont 
    \end{justify}
    \vspace{-2em}
  \ifx#6\else\printforarray{#6}\fi
  \vspace{2ex}
}
% all this from here 
\catcode`*=\active\catcode`|=\active
\newcommand{\printforarray}[1]{%
    \vspace{0em}
    \begin{itemize}[noitemsep, leftmargin=*]
    \ForArray{,;}{*}{|}%
        {*\par|\item *}%
        {#1}%
    \end{itemize}
}
\catcode`*=12 \catcode`|=12
% to here is needed for lists

