Name:           sim6809
Version:        1.0.0
Release:        1%{?dist}
Summary:        Headless Motorola 6809 simulator with OS-9 and FLEX environments

License:        MIT
URL:            https://github.com/retrotinker/sim6809
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
# for %%check
BuildRequires:  lwtools
BuildRequires:  python3
BuildRequires:  groff-base
# sim6809 and srec2flex were part of plm09 before 0.5.0
Conflicts:      plm09 < 0.5.0

%description
sim6809 is a command-line simulator for the Motorola MC6809. It loads
S-records, Intel HEX or FLEX binary files, runs them with no display, and
reports the result through standard output and its exit status, which
makes it a good fit for automated tests.

It emulates the complete MC6809 instruction set and interrupts, a small
memory-mapped I/O block with a timer, an MC6850 ACIA and an FT245RL FIFO,
and OS-9 and FLEX program environments on host files. It also includes
srec2flex, which converts S-records to FLEX binary (.CMD) files.

%prep
%autosetup

%build
%set_build_flags
%make_build WERROR=

%install
%make_install PREFIX=%{_prefix} BINDIR=%{_bindir} MANDIR=%{_mandir} WERROR=

%check
make WERROR= test

%files
%license LICENSE
%doc README.md docs/sim6809.pdf
%{_bindir}/sim6809
%{_bindir}/srec2flex
%{_mandir}/man1/sim6809.1*
%{_mandir}/man1/srec2flex.1*

%changelog
* Tue Nov 10 2026 John W. Linville <linville@tuxdriver.com> - 1.0.0-1
- First package, split out of plm09 0.4.6
