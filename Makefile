SLAX:=slax-64bit-9.11.0
default:$(SLAX)_winehq-stable.iso

$(SLAX).iso:
	wget http://ftp.sh.cvut.cz/slax/Slax-9.x/$(SLAX).iso -O $(SLAX).iso
	echo "1c9d92503e295ddf44c0a96c3b064098 $(SLAX).iso" | md5sum -c -

$(SLAX)_sshd.iso: $(SLAX).iso
	mkdir -p $(dir $@) $(SLAX).mount
	-mount -o loop -t iso9660 $(SLAX).iso $(SLAX).mount
	cp -an $(SLAX).mount $(SLAX)_sshd
	cp -an sshd.sb $(SLAX)_sshd/slax/modules
	$(call genisoimage,$@)
	qemu-system-x86_64 -enable-kvm -m 12G -cdrom $(SLAX)_sshd.iso -net nic -net user,hostfwd=tcp::2222-:22 -nographic & echo $$! > KVM_PID

winehq-stable.sb: $(SLAX)_sshd.iso
	cd ansible && ansible-playbook -e "slax_version=$(SLAX)" main.yml

$(SLAX)_winehq-stable.iso: winehq-stable.sb
	cp -a $(SLAX).mount $(SLAX)_winehq-stable
	cp -a winehq-stable.sb $(SLAX)_winehq-stable/slax/modules
	$(call genisoimage,$@)
	# cat KVM_PID | xargs kill 

clean:
		
	-(cat KVM_PID |xargs -I{} kill {} ) 2>/dev/null || true
	umount $(SLAX).mount || true
	rm -rf $(SLAX).mount $(SLAX)_winehq-stable $(SLAX)_sshd 
	rm -f winehq-stable.sb $(SLAX)_sshd.iso $(SLAX)_winehq-stable.iso
	rm -f KVM_PID

define genisoimage
	cd $(basename $(1)) && genisoimage -o ../$(1) -v -J -R -D -A slax -V slax \
                -no-emul-boot \
                -boot-info-table \
                -boot-load-size 4 \
                -input-charset utf-8 \
                -b slax/boot/isolinux.bin \
                -c slax/boot/isolinux.boot \
                .
endef
