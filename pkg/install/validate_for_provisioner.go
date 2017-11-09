package install

import (
	"fmt"
	"regexp"

	"github.com/apprenda/kismatic/pkg/util"
)

// ValidatePlanForProvisioner runs validation against the installation plan.
// It is similar to ValidatePlan but for a smaller set of rules that are critical to provisioning infrastructure.
func ValidatePlanForProvisioner(p *Plan) (bool, []error) {
	v := newValidator()
	v.validate(&p.Provisioner)
	v.validate(&provisionerNodeList{Nodes: p.getAllNodes()})
	v.validateWithErrPrefix("Etcd nodes", &provisionerNodeGroup{NodeGroup: p.Etcd})
	v.validateWithErrPrefix("Master nodes", &provisionerMasterNodeGroup{MasterNodeGroup: p.Master})
	v.validateWithErrPrefix("Worker nodes", &provisionerNodeGroup{NodeGroup: p.Worker})
	v.validateWithErrPrefix("Ingress nodes", &provisionerNodeGroup{NodeGroup: NodeGroup(p.Ingress)})
	return v.valid()
}

type provisionerNodeGroup struct {
	NodeGroup
}

type provisionerMasterNodeGroup struct {
	MasterNodeGroup
}

type provisionerOptionalNodeGroup provisionerNodeGroup

type provisionerNode struct {
	Node
}

type provisionerNodeList struct {
	Nodes []Node
}

func (p *Provisioner) validate() (bool, []error) {
	v := newValidator()
	if p.Provider == "" {
		v.addError(fmt.Errorf("Provisioner provider cannot be empty"))
		return v.valid()
	}
	if !util.Contains(p.Provider, InfrastructureProvisioners()) {
		v.addError(fmt.Errorf("%q is not a valid provisioner provider. Options are %v", p.Provider, InfrastructureProvisioners()))
	}
	// TODO run any validation required
	// Would also be a good time to check for the ENV vars
	if p.Provider != "" {

	}
	return v.valid()
}

func (mng *provisionerMasterNodeGroup) validate() (bool, []error) {
	v := newValidator()

	if len(mng.Nodes) <= 0 {
		v.addError(fmt.Errorf("At least one node is required"))
	}
	if mng.ExpectedCount <= 0 {
		v.addError(fmt.Errorf("Node count must be greater than 0"))
	}
	if len(mng.Nodes) != mng.ExpectedCount && (len(mng.Nodes) > 0 && mng.ExpectedCount > 0) {
		v.addError(fmt.Errorf("Expected node count (%d) does not match the number of nodes provided (%d)", mng.ExpectedCount, len(mng.Nodes)))
	}
	for i, n := range mng.Nodes {
		v.validateWithErrPrefix(fmt.Sprintf("Node #%d", i+1), &provisionerNode{Node: n})
	}

	if mng.LoadBalancedFQDN != "${load_balanced_fqdn}" {
		v.addError(fmt.Errorf("Load balanced FQDN is not a valid templated string, should be '${load_balanced_fqdn}'"))
	}

	if mng.LoadBalancedShortName != "${load_balanced_short_name}" {
		v.addError(fmt.Errorf("Load balanced shortname is not a valid templated string, should be '${load_balanced_short_name}'"))
	}

	return v.valid()
}

func (nl provisionerNodeList) validate() (bool, []error) {
	v := newValidator()
	v.addError(validateNoDuplicateNodeInfo(nl.Nodes)...)
	return v.valid()
}

func (ng *provisionerNodeGroup) validate() (bool, []error) {
	v := newValidator()
	if ng == nil || len(ng.Nodes) <= 0 {
		v.addError(fmt.Errorf("At least one node is required"))
	}
	if ng.ExpectedCount <= 0 {
		v.addError(fmt.Errorf("Node count must be greater than 0"))
	}
	if len(ng.Nodes) != ng.ExpectedCount && (len(ng.Nodes) > 0 && ng.ExpectedCount > 0) {
		v.addError(fmt.Errorf("Expected node count (%d) does not match the number of nodes provided (%d)", ng.ExpectedCount, len(ng.Nodes)))
	}
	for i, n := range ng.Nodes {
		v.validateWithErrPrefix(fmt.Sprintf("Node #%d", i+1), &provisionerNode{Node: n})
	}

	return v.valid()
}

func (ong *provisionerOptionalNodeGroup) validate() (bool, []error) {
	if ong == nil {
		return true, nil
	}
	if len(ong.Nodes) == 0 && ong.ExpectedCount == 0 {
		return true, nil
	}
	if len(ong.Nodes) != ong.ExpectedCount {
		return false, []error{fmt.Errorf("Expected node count (%d) does not match the number of nodes provided (%d)", ong.ExpectedCount, len(ong.Nodes))}
	}
	ng := provisionerNodeGroup(*ong)
	return ng.validate()
}

func (n *provisionerNode) validate() (bool, []error) {
	v := newValidator()
	// Hostnames need to be templates ${hostname_#}
	template, err := regexp.MatchString(`\${host_\d+}`, n.Host)
	if err != nil {
		v.addError(fmt.Errorf("Could not determine if %q is a templated value: %v", n.Host, err))
	}
	if !template {
		v.addError(fmt.Errorf("%q is not a valid IP templated string, should be '${host_#}'", n.IP))
	}
	// IPs need to be templates ${ip_#}
	template, err = regexp.MatchString(`\${ip_\d+}`, n.IP)
	if err != nil {
		v.addError(fmt.Errorf("Could not determine if %q is a templated value: %v", n.IP, err))
	}
	if !template {
		v.addError(fmt.Errorf("%q is not a valid IP templated string, should be '${ip_#}'", n.IP))
	}
	// IPs need to be templates ${internalip_#}
	template, err = regexp.MatchString(`\${internalip_\d+}`, n.InternalIP)
	if err != nil {
		v.addError(fmt.Errorf("Could not determine if %q is a templated value: %v", n.InternalIP, err))
	}
	if !template && n.InternalIP != "" {
		v.addError(fmt.Errorf("%q is not a valid InternalIP templated string, should be '${internalip_#}'", n.InternalIP))
	}
	return v.valid()
}
