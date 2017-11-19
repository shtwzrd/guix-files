(use-modules (gnu)
             (gnu system nss)
             (gnu services base)
             (gnu services desktop)
             (gnu services avahi)
             (gnu services networking)
             (gnu services xorg)
             (gnu services dbus))

(use-package-modules certs nvi admin libusb freedesktop avahi xdisorg suckless fonts)

(define libinput.conf "
# Match on all types of devices but tablet devices and joysticks
Section \"InputClass\"
        Identifier \"libinput pointer catchall\"
        MatchIsPointer \"on\"
        MatchDevicePath \"/dev/input/event*\"
        Driver \"libinput\"
EndSection

Section \"InputClass\"
        Identifier \"libinput keyboard catchall\"
        MatchIsKeyboard \"on\"
        MatchDevicePath \"/dev/input/event*\"
        Driver \"libinput\"
EndSection

Section \"InputClass\"
        Identifier \"libinput touchpad catchall\"
        MatchIsTouchpad \"on\"
        MatchDevicePath \"/dev/input/event*\"
        Driver \"libinput\"
        Option \"ClickMethod\" \"clickfinger\"
        Option \"Tapping\" \"on\"
EndSection

Section \"InputClass\"
        Identifier \"libinput touchscreen catchall\"
        MatchIsTouchscreen \"on\"
        MatchDevicePath \"/dev/input/event*\"
        Driver \"libinput\"
EndSection

Section \"InputClass\"
        Identifier \"libinput tablet catchall\"
        MatchIsTablet \"on\"
        MatchDevicePath \"/dev/input/event*\"
        Driver \"libinput\"
EndSection
")

(operating-system
  (host-name "t520")
  (timezone "Europe/Copenhagen")
  (locale "en_US.utf8")

  (bootloader (grub-configuration (device "/dev/sda")))

  (mapped-devices
    (list (mapped-device
            (source (uuid "d9042cc1-f42f-4165-aade-1ecd954e334c"))
            (target "rootvol")
            (type luks-device-mapping))))

  (file-systems (cons (file-system
                        (device "rootvol")
                        (title 'label)
                        (mount-point "/")
                        (dependencies mapped-devices)
                        (type "ext4"))
                      %base-file-systems))

  (users (cons (user-account
                (name "blu")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video"))
                (home-directory "/home/blu"))
               %base-user-accounts))

  (packages (cons* nvi
                   wpa-supplicant
                   font-dejavu
                   nss-certs                      ;for HTTPS access
                   %base-packages))

(services
  (cons* (slim-service
           #:allow-empty-passwords? #f
	   #:auto-login? #f
           #:startx (xorg-start-command
		   #:configuration-file
		     (xorg-configuration-file
		       #:extra-config (list libinput.conf))))
         ;; Screen lockers are a pretty useful thing and these are small.
         (screen-locker-service slock)
         (screen-locker-service xlockmore "xlock")
         ;; Add udev rules for MTP devices so that non-root users can access
         ;; them.
         (simple-service 'mtp udev-service-type (list libmtp))
         (xfce-desktop-service)

         ;; The D-Bus clique.
         (service network-manager-service-type)
         (service wpa-supplicant-service-type)    ;needed by NetworkManager
;;         (avahi-service)
;;         (udisks-service)
;;         (upower-service)
;;         (accountsservice-service)
;;         (colord-service)
;;         (geoclue-service)
         (polkit-service)
         (elogind-service)
         (dbus-service)
         %base-services))


  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))

