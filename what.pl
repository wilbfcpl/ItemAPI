 $out = <<EOT;
            Quick Start
            ───────────
            • To add a package to your runtime, type "state install <package name>"
            • Learn more about how to use the State Tool, type "state learn"
EOT
$out =~ s/^ +//gm;
print $out;