Name:       harbour-electrocosm

Summary:    Electrocosm - Your EV Cosmic Horror
Version:    0.1
Release:    1
License:    LICENSE
BuildArch:  noarch
URL:        http://example.org/
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   libsailfishapp-launcher
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.3
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
This app helps locate Electroverse-compatible EV charging stations across the globe, with thousands of chargers on Europe's biggest EV charging network.
Created with friendly support from Claude, who was kind enough to reverse-engineer the relevant API.
This is an early version created solely for personal use, which was never intended for public release. I'm sharing it in the hope that it might be useful to others, but please don't expect perfection.


%prep
%setup -q -n %{name}-%{version}

%build

%qmake5 

%make_build


%install
%qmake5_install


desktop-file-install --delete-original         --dir %{buildroot}%{_datadir}/applications                %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%defattr(0644,root,root,-)
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
