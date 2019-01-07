package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	log "github.com/Sirupsen/logrus"
	"github.com/fatih/structs"
	"github.com/gorilla/mux"
	"github.com/malice-plugins/pkgs/database"
	"github.com/malice-plugins/pkgs/database/elasticsearch"
	"github.com/malice-plugins/pkgs/utils"
	"github.com/parnurzeal/gorequest"
	"github.com/pkg/errors"
	"github.com/urfave/cli"
)

const (
	name     = "kaspersky"
	category = "av"
)

var (
	// Version stores the plugin's version
	Version string
	// BuildTime stores the plugin's build time
	BuildTime string
	// LicenseKey stores the valid Dr.Web license key
	LicenseKey string
	path       string
	hash       string
	// es is the elasticsearch database object
	es elasticsearch.Database
)

type pluginResults struct {
	ID   string      `json:"id" structs:"id,omitempty"`
	Data ResultsData `json:"kaspersky" structs:"kaspersky"`
}

// Kaspersky json object
type Kaspersky struct {
	Results ResultsData `json:"kaspersky"`
}

// ResultsData json object
type ResultsData struct {
	Infected bool   `json:"infected" structs:"infected"`
	Result   string `json:"result" structs:"result"`
	Engine   string `json:"engine" structs:"engine"`
	Database string `json:"database" structs:"database"`
	Updated  string `json:"updated" structs:"updated"`
	MarkDown string `json:"markdown,omitempty" structs:"markdown,omitempty"`
	Error    string `json:"error,omitempty" structs:"error,omitempty"`
}

func assert(err error) {
	if err != nil {
		// skip exit code 13 (which means a virus was found)
		if err.Error() != "exit status 1" {
			log.WithFields(log.Fields{
				"plugin":   name,
				"category": category,
				"path":     path,
			}).Fatal(err)
		}
	}
}

// AvScan performs antivirus scan
func AvScan(timeout int) Kaspersky {

	var output string
	var sErr error

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeout)*time.Second)
	defer cancel()

	expired, err := didLicenseExpire(ctx)
	assert(err)
	if expired {
		err = updateLicense(ctx)
		assert(err)
	}

	// kaspersky needs to have the daemon started first
	log.Debug("/etc/init.d/kav4fs-supervisor start")
	configd := exec.CommandContext(ctx, "/etc/init.d/kav4fs-supervisor", "start")
	_, err = configd.Output()
	assert(err)
	defer configd.Process.Kill()

	time.Sleep(10 * time.Second)

	log.Debug("running kav4fs-control --scan-file")
	output, sErr = utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--scan-file", path)
	if sErr != nil {
		// If fails try a second time
		time.Sleep(10 * time.Second)
		log.Debug("re-running kav4fs-control --scan-file")
		output, sErr = utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--scan-file", path)
	}

	virusInfo, err := utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--top-viruses", "1")
	assert(err)

	results, err := ParseKasperskyOutput(output, virusInfo, sErr)

	return Kaspersky{Results: results}
}

// ParseKasperskyOutput convert kaspersky output into ResultsData struct
func ParseKasperskyOutput(kasperskyOut, virusInfo string, kasperskyErr error) (ResultsData, error) {

	log.WithFields(log.Fields{
		"plugin":   name,
		"category": category,
		"path":     path,
	}).Debug("Kaspersky Output: ", kasperskyOut)

	log.WithFields(log.Fields{
		"plugin":   name,
		"category": category,
		"path":     path,
	}).Debug("Kaspersky Virus Info: ", virusInfo)

	if kasperskyErr != nil {
		// if kasperskyErr.Error() == "exit status 119" {
		// 	return ResultsData{Error: "ScanEngine is not available"}, kasperskyErr
		// }
		return ResultsData{Error: kasperskyErr.Error()}, kasperskyErr
	}

	kaspersky := ResultsData{
		Infected: false,
		Engine:   getKasperskyVersion(),
		Database: getKasperskyDatabase(),
		Updated:  getUpdatedDate(),
	}

	for _, line := range strings.Split(kasperskyOut, "\n") {
		if len(line) != 0 {
			if strings.Contains(line, "Threats found:       1") {
				kaspersky.Infected = true
				for _, line := range strings.Split(virusInfo, "\n") {
					if len(line) != 0 {
						if strings.Contains(line, "Virus name:") {
							kaspersky.Result = strings.TrimSpace(strings.TrimPrefix(line, "Virus name:"))
						}
					}
				}
			}
		}
	}

	return kaspersky, nil
}

func getKasperskyVersion() string {

	versionOut, err := utils.RunCommand(nil, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "-S", "--app-info")
	assert(err)

	log.Debug("Kaspersky Version: ", versionOut)
	for _, line := range strings.Split(versionOut, "\n") {
		if len(line) != 0 {
			if strings.Contains(line, "Version:") {
				return strings.TrimSpace(strings.TrimPrefix(line, "Version:"))
			}
		}
	}
	return "error"
}

func getKasperskyDatabase() string {

	databaseOut, err := utils.RunCommand(nil, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--get-stat", "Update")
	assert(err)

	log.Debug("Kaspersky Database: ", databaseOut)
	for _, line := range strings.Split(databaseOut, "\n") {
		if len(line) != 0 {
			if strings.Contains(line, "Current AV databases records:") {
				return strings.TrimSpace(strings.TrimPrefix(line, "Current AV databases records:"))
			}
		}
	}
	return "error"
}

func parseUpdatedDate(date string) string {
	layout := "Mon, 02 Jan 2006 15:04:05 +0000"
	t, _ := time.Parse(layout, date)
	return fmt.Sprintf("%d%02d%02d", t.Year(), t.Month(), t.Day())
}

func getUpdatedDate() string {
	if _, err := os.Stat("/opt/malice/UPDATED"); os.IsNotExist(err) {
		return BuildTime
	}
	updated, err := ioutil.ReadFile("/opt/malice/UPDATED")
	assert(err)
	return string(updated)
}

func updateAV(ctx context.Context) error {
	// kaspersky needs to have the daemon started first
	configd := exec.Command("/etc/init.d/kav4fs-supervisor", "start")
	_, err := configd.Output()
	if err != nil {
		return err
	}
	defer configd.Process.Kill()
	time.Sleep(20 * time.Second)

	fmt.Println("Updating Kaspersky...")
	fmt.Println(utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "-T", "--start-task", "6", "--progress"))
	// Update UPDATED file
	t := time.Now().Format("20060102")
	err = ioutil.WriteFile("/opt/malice/UPDATED", []byte(t), 0644)
	return err
}

func updateLicense(ctx context.Context) error {
	// kaspersky needs to have the daemon started first
	configd := exec.CommandContext(ctx, "/etc/init.d/kav4fs-supervisor", "start")
	_, err := configd.Output()
	if err != nil {
		return err
	}
	defer configd.Process.Kill()
	time.Sleep(10 * time.Second)

	// check for exec context timeout
	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Errorf("command updateLicense() timed out")
	}

	log.Debug("updating Kaspersky license")
	if len(LicenseKey) > 0 {
		log.Debugln(utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--revoke-active-key", LicenseKey))
		log.Debugln(utils.RunCommand(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--install-active-key", LicenseKey))
	}

	return nil
}

func didLicenseExpire(ctx context.Context) (bool, error) {
	// kaspersky needs to have the daemon started first
	configd := exec.CommandContext(ctx, "/etc/init.d/kav4fs-supervisor", "start")
	_, err := configd.Output()
	if err != nil {
		return false, err
	}
	defer configd.Process.Kill()
	time.Sleep(1 * time.Second)

	log.Debug("checking Kaspersky license")
	license := exec.CommandContext(ctx, "/opt/kaspersky/kav4fs/bin/kav4fs-control", "--query-status")
	lOut, err := license.Output()
	if err != nil {
		return false, err
	}
	for _, line := range strings.Split(string(lOut), "\n") {
		if len(line) != 0 {
			if strings.Contains(line, "License status:") {
				return strings.Contains(line, "Valid"), nil
			}
		}
	}

	log.WithFields(log.Fields{"output": string(lOut)}).Debug("licence expired")
	return true, nil
}

func generateMarkDownTable(a Kaspersky) string {
	var tplOut bytes.Buffer

	t := template.Must(template.New("kaspersky").Parse(tpl))

	err := t.Execute(&tplOut, a)
	if err != nil {
		log.Println("executing template:", err)
	}

	return tplOut.String()
}

func printStatus(resp gorequest.Response, body string, errs []error) {
	fmt.Println(body)
}

func webService() {
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/scan", webAvScan).Methods("POST")
	log.WithFields(log.Fields{
		"plugin":   name,
		"category": category,
	}).Info("web service listening on port :3993")
	log.Fatal(http.ListenAndServe(":3993", router))
}

func webAvScan(w http.ResponseWriter, r *http.Request) {

	r.ParseMultipartForm(32 << 20)
	file, header, err := r.FormFile("malware")
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintln(w, "Please supply a valid file to scan.")
		log.WithFields(log.Fields{
			"plugin":   name,
			"category": category,
		}).Error(err)
	}
	defer file.Close()

	log.WithFields(log.Fields{
		"plugin":   name,
		"category": category,
	}).Debug("Uploaded fileName: ", header.Filename)

	tmpfile, err := ioutil.TempFile("/malware", "web_")
	assert(err)
	defer os.Remove(tmpfile.Name()) // clean up

	data, err := ioutil.ReadAll(file)
	assert(err)

	if _, err = tmpfile.Write(data); err != nil {
		assert(err)
	}
	if err = tmpfile.Close(); err != nil {
		assert(err)
	}

	// Do AV scan
	path = tmpfile.Name()
	kaspersky := AvScan(60)

	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(kaspersky); err != nil {
		assert(err)
	}
}

func main() {

	cli.AppHelpTemplate = utils.AppHelpTemplate
	app := cli.NewApp()

	app.Name = "kaspersky"
	app.Author = "blacktop"
	app.Email = "https://github.com/blacktop"
	app.Version = Version + ", BuildTime: " + BuildTime
	app.Compiled, _ = time.Parse("20060102", BuildTime)
	app.Usage = "Malice Kaspersky AntiVirus Plugin"
	app.Flags = []cli.Flag{
		cli.BoolFlag{
			Name:  "verbose, V",
			Usage: "verbose output",
		},
		cli.StringFlag{
			Name:        "elasticsearch",
			Value:       "",
			Usage:       "elasticsearch url for Malice to store results",
			EnvVar:      "MALICE_ELASTICSEARCH_URL",
			Destination: &es.URL,
		},
		cli.BoolFlag{
			Name:  "table, t",
			Usage: "output as Markdown table",
		},
		cli.BoolFlag{
			Name:   "callback, c",
			Usage:  "POST results back to Malice webhook",
			EnvVar: "MALICE_ENDPOINT",
		},
		cli.BoolFlag{
			Name:   "proxy, x",
			Usage:  "proxy settings for Malice webhook endpoint",
			EnvVar: "MALICE_PROXY",
		},
		cli.IntFlag{
			Name:   "timeout",
			Value:  120,
			Usage:  "malice plugin timeout (in seconds)",
			EnvVar: "MALICE_TIMEOUT",
		},
	}
	app.Commands = []cli.Command{
		{
			Name:    "update",
			Aliases: []string{"u"},
			Usage:   "Update virus definitions",
			Action: func(c *cli.Context) error {
				return updateAV(nil)
			},
		},
		{
			Name:  "web",
			Usage: "Create a Kaspersky scan web service",
			Action: func(c *cli.Context) error {
				webService()
				return nil
			},
		},
	}
	app.Action = func(c *cli.Context) error {

		var err error

		if c.Bool("verbose") {
			log.SetLevel(log.DebugLevel)
		}

		if c.Args().Present() {
			path, err = filepath.Abs(c.Args().First())
			assert(err)

			if _, err = os.Stat(path); os.IsNotExist(err) {
				assert(err)
			}

			hash = utils.GetSHA256(path)

			kaspersky := AvScan(c.Int("timeout"))
			kaspersky.Results.MarkDown = generateMarkDownTable(kaspersky)
			// upsert into Database
			if len(c.String("elasticsearch")) > 0 {
				err := es.Init()
				if err != nil {
					return errors.Wrap(err, "failed to initalize elasticsearch")
				}
				err = es.StorePluginResults(database.PluginResults{
					ID:       utils.Getopt("MALICE_SCANID", hash),
					Name:     name,
					Category: category,
					Data:     structs.Map(kaspersky.Results),
				})
				if err != nil {
					return errors.Wrapf(err, "failed to index malice/%s results", name)
				}
			}

			if c.Bool("table") {
				fmt.Printf(kaspersky.Results.MarkDown)
			} else {
				kaspersky.Results.MarkDown = ""
				kasperskyJSON, err := json.Marshal(kaspersky)
				assert(err)
				if c.Bool("callback") {
					request := gorequest.New()
					if c.Bool("proxy") {
						request = gorequest.New().Proxy(os.Getenv("MALICE_PROXY"))
					}
					request.Post(os.Getenv("MALICE_ENDPOINT")).
						Set("X-Malice-ID", utils.Getopt("MALICE_SCANID", hash)).
						Send(string(kasperskyJSON)).
						End(printStatus)

					return nil
				}
				fmt.Println(string(kasperskyJSON))
			}
		} else {
			log.WithFields(log.Fields{
				"plugin":   name,
				"category": category,
			}).Fatal(fmt.Errorf("Please supply a file to scan with malice/%s", name))
		}
		return nil
	}

	err := app.Run(os.Args)
	assert(err)
}
