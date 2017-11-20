package cli

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

type dashboardOpts struct {
	dashboardURLMode   bool
	generatedAssetsDir string
}

const url = "http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login"

// NewCmdDashboard opens or displays the dashboard URL
func NewCmdDashboard(in io.Reader, out io.Writer) *cobra.Command {
	opts := &dashboardOpts{}

	cmd := &cobra.Command{
		Use:   "dashboard",
		Short: "Opens/displays the kubernetes dashboard URL of the cluster",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) != 0 {
				return fmt.Errorf("Unexpected args: %v", args)
			}
			return doDashboard(in, out, opts)
		},
	}

	cmd.Flags().StringVar(&opts.generatedAssetsDir, "generated-assets-dir", "generated", "path to the directory where assets generated during the installation process will be stored")
	cmd.Flags().BoolVar(&opts.dashboardURLMode, "url", false, "Display the kubernetes dashboard URL instead of opening it in the default browser")
	return cmd
}

func doDashboard(in io.Reader, out io.Writer, opts *dashboardOpts) error {
	if opts.dashboardURLMode {
		fmt.Fprintln(out, url)
		return nil
	}

	kubeconfig := filepath.Join(opts.generatedAssetsDir, "kubeconfig")
	if stat, err := os.Stat(kubeconfig); os.IsNotExist(err) || stat.IsDir() {
		return fmt.Errorf("Did not find required kubeconfig file %q", kubeconfig)
	}

	fmt.Fprintf(out, "Opening kubernetes dashboard in default browser...\nUse the kubeconfig in '%s/dashboard-admin-kubeconfig'\n\n", opts.generatedAssetsDir)
	if err := browser.OpenURL(url); err != nil {
		fmt.Fprintf(out, "Unexpected error opening the kubernetes dashboard: %v. You may access it at %q", err, url)
	}

	cmd := exec.Command("./kubectl", "proxy", "--kubeconfig", kubeconfig)
	cmd.Stdin = in
	cmd.Stdout = out
	cmd.Stderr = out
	err := cmd.Run()
	if err != nil {
		return fmt.Errorf("Error running kubectl proxy: %v", err)
	}

	return nil
}
