## kismatic reset

reset any changes made to the hosts by 'apply'

### Synopsis


reset any changes made to the hosts by 'apply'

```
kismatic reset [flags]
```

### Options

```
      --force                         do not prompt
      --generated-assets-dir string   path to the directory where assets generated during the installation process will be stored (default "generated")
  -h, --help                          help for reset
      --limit stringSlice             comma-separated list of hostnames to limit the execution to a subset of nodes
  -o, --output string                 installation output format (options "simple"|"raw") (default "simple")
  -f, --plan-file string              path to the installation plan file (default "kismatic-cluster.yaml")
      --remove-assets                 remove generated-assets-dir
      --verbose                       enable verbose logging from the installation
```

### SEE ALSO
* [kismatic](kismatic.md)	 - kismatic is the main tool for managing your Kubernetes cluster

###### Auto generated by spf13/cobra on 11-Apr-2018