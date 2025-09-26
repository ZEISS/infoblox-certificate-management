package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	corev1 "k8s.io/api/core/v1"
	extapi "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"

	"github.com/cert-manager/cert-manager/pkg/acme/webhook/apis/acme/v1alpha1"
	"github.com/cert-manager/cert-manager/pkg/acme/webhook/cmd"
)

var GroupName = os.Getenv("GROUP_NAME")

func main() {
	if GroupName == "" {
		panic("GROUP_NAME must be specified")
	}

	cmd.RunWebhookServer(GroupName,
		&InfoBloxSolver{},
	)
}

type InfoBloxSolver struct {
	client *kubernetes.Clientset
}

type infobloxProviderConfig struct {
	EsbApiKey        corev1.SecretKeySelector `json:"esbApiKey"`
	InfobloxUser     corev1.SecretKeySelector `json:"infobloxUser"`
	InfobloxPassword corev1.SecretKeySelector `json:"infobloxPassword"`
	DnsName          string                   `json:"dnsName"`
}

type Config struct {
	EsbApiKey        string
	InfobloxUser     string
	InfobloxPassword string
}

func (c *InfoBloxSolver) Name() string {
	return "infoblox-solver"
}

func (c *InfoBloxSolver) Present(ch *v1alpha1.ChallengeRequest) error {
	config, err := c.getConfig(ch)
	if err != nil {
		return fmt.Errorf("error loading config")
	}

	data := map[string]any{
		"name": strings.TrimSuffix(ch.ResolvedFQDN, "."),
		"text": ch.Key,
		"view": "Internet",
		"ttl":  3600,
	}

	jsonBody, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("error formating json body")
	}

	req, err := http.NewRequest("POST", "https://esb.zeiss.com/public/api/infoblox/record/txt", bytes.NewBuffer(jsonBody))
	if err != nil {
		panic(err)
	}
	log.Printf("adding record %v with value %v", strings.TrimSuffix(ch.ResolvedFQDN, "."), ch.Key)

	req.SetBasicAuth(config.InfobloxUser, config.InfobloxPassword)
	req.Header.Add("EsbApi-Subscription-Key", config.EsbApiKey)
	req.Header.Add("Content-type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	log.Printf("status code of propagation request %v of zone %v", resp.StatusCode, strings.TrimSuffix(ch.ResolvedZone, "."))

	return nil
}

func (c *InfoBloxSolver) CleanUp(ch *v1alpha1.ChallengeRequest) error {
	config, err := c.getConfig(ch)
	if err != nil {
		return fmt.Errorf("error loading config")
	}

	recordName := strings.Split(ch.ResolvedFQDN, ".")[0] + "." + strings.Split(ch.ResolvedFQDN, ".")[1]
	requestUrl := fmt.Sprintf("https://esb.zeiss.com/public/api/infoblox/record/txt?zone=%s&name=%s&view=Internet", strings.TrimSuffix(ch.ResolvedZone, "."), recordName)

	req, err := http.NewRequest("GET", requestUrl, http.NoBody)
	if err != nil {
		return fmt.Errorf("error creating GET request for txt record: %v", err)
	}

	req.SetBasicAuth(config.InfobloxUser, config.InfobloxPassword)
	req.Header.Add("EsbApi-Subscription-Key", config.EsbApiKey)
	req.Header.Add("Content-type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error getting textrecord: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	var res []map[string]interface{}
	json.Unmarshal([]byte(string(body)), &res)

	// we delete all records with the same name (e.g. _acme-challenge.test.zeiss.com) in case of duplications
	for _, r := range res {
		req, err = http.NewRequest("DELETE", fmt.Sprintf("https://esb.zeiss.com/public/api/infoblox/record?reference=%s", r["_ref"].(string)), http.NoBody)
		if err != nil {
			return fmt.Errorf("error creating DELETE request: %v", err)
		}

		log.Printf("deleting record with reference %v", r["_ref"].(string))

		req.SetBasicAuth(config.InfobloxUser, config.InfobloxPassword)
		req.Header.Add("EsbApi-Subscription-Key", config.EsbApiKey)
		req.Header.Add("Content-type", "application/json")

		resp, err = client.Do(req)
		if err != nil {
			return fmt.Errorf("error deleting textrecord: %v", err)
		}
		defer resp.Body.Close()

		log.Printf("status code of deletion request %v of zone %v", resp.StatusCode, strings.TrimSuffix(ch.ResolvedZone, "."))
	}

	return nil
}

func (c *InfoBloxSolver) Initialize(kubeClientConfig *rest.Config, stopCh <-chan struct{}) error {
	cl, err := kubernetes.NewForConfig(kubeClientConfig)
	if err != nil {
		return err
	}

	c.client = cl
	return nil
}

func (c *InfoBloxSolver) getConfig(ch *v1alpha1.ChallengeRequest) (Config, error) {
	cfg, err := loadConfig(ch.Config)
	if err != nil {
		return Config{}, err
	}

	esbApiKey, err := c.getSecret(cfg.EsbApiKey, ch.ResourceNamespace)
	if err != nil {
		return Config{}, fmt.Errorf("error getting secret %s with err %v", "esbApiKey", err)
	}

	infobloxUser, err := c.getSecret(cfg.InfobloxUser, ch.ResourceNamespace)
	if err != nil {
		return Config{}, fmt.Errorf("error getting secret %s with err %v", "infobloxUser", err)
	}

	infobloxPassword, err := c.getSecret(cfg.InfobloxPassword, ch.ResourceNamespace)
	if err != nil {
		return Config{}, fmt.Errorf("error getting secret %s with err %v", "infobloxPassword", err)
	}

	return Config{
		EsbApiKey:        esbApiKey,
		InfobloxUser:     infobloxUser,
		InfobloxPassword: infobloxPassword,
	}, nil
}

func (c *InfoBloxSolver) getSecret(selector corev1.SecretKeySelector, namespace string) (string, error) {
	secret, err := c.client.CoreV1().Secrets(namespace).Get(context.Background(), selector.Name, metav1.GetOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to load secret %q; %v", namespace+"/"+selector.Name, err)
	}

	if data, ok := secret.Data[selector.Key]; ok {
		return string(data), nil
	}

	return "", fmt.Errorf("key not found %q in secret '%s/%s'", selector.Key, namespace, selector.Name)
}

func loadConfig(cfgJSON *extapi.JSON) (infobloxProviderConfig, error) {
	cfg := infobloxProviderConfig{}
	// handle the 'base case' where no configuration has been provided
	if cfgJSON == nil {
		return cfg, nil
	}
	if err := json.Unmarshal(cfgJSON.Raw, &cfg); err != nil {
		return cfg, fmt.Errorf("error decoding solver config: %v", err)
	}

	return cfg, nil
}
