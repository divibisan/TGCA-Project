import requests
import json
import sys
import re


def main():
    # URLs for different endpoints
    cases_endpt = 'https://api.gdc.cancer.gov/cases'
    projects_endpt = 'https://api.gdc.cancer.gov/projects'
    files_endpt = 'https://api.gdc.cancer.gov/files'
    data_endpt = 'https://api.gdc.cancer.gov/legacy/data'

    # Require command line argument
    if len(sys.argv) < 2:
        print("ERROR: missing disease name")
        quit()

    # First command line argument = disease name
    disease_name = sys.argv[1]

    # If 2 arguments provided, use the second for program name. TCGA = default
    if len(sys.argv) == 3:
        program_name = sys.argv[2]
    else:
        program_name = "TCGA"

    #####################
    # GET DISEASE CASES #

    case_count = 2000
    filters = op_and([op_equals("project.name", disease_name),
                      op_equals("project.program.name", program_name),
                      op_equals("diagnoses.vital_status", "dead")
                      ])
    params = {
        'filters': json.dumps(filters),
        'size': case_count,
        'fields': 'id,'
                  'case_id,'
                  'submitter_id,'
                  'demographic.gender,'
                  'diagnoses.vital_status,'
                  'diagnoses.days_to_death,'
                  'project.name,'
                  'sample_ids,'

    }

    response = requests.get(cases_endpt, params=params)

    cases = get_values(response, "id", ["diagnoses.vital_status",
                                        "diagnoses.days_to_death",
                                        "sample_ids",
                                        "case_id"])

    #############################################
    # GET GENE EXPRESSION FILES FOR THOSE CASES #
    filters = op_and([op_equals("data_category", "Transcriptome Profiling"),
                      op_equals("analysis.workflow_type", "HTSeq - Counts"),
                      op_in("cases.case_id", list(cases.keys()))
                      ])
    params = {
        'filters': json.dumps(filters),
        'size': 10000,
        'fields': 'cases.case_id,'
                  'cases.diagnoses.days_to_death,'
                  'cases.diagnoses.vital_status,'
                  'cases.samples.sample_type,'
                  'cases.demographic.gender,'
                  'file_name'}

    response = requests.post(files_endpt, data=params)

    file_ids = get_values(response, "id")

    file_metadata = ["cases.case_id",
                     "cases.diagnoses.days_to_death",
                     "cases.diagnoses.vital_status",
                     "cases.samples.sample_type",
                     "cases.demographic.gender"]

    files = get_values(response, "file_name", file_metadata)

    ###################
    # OUTPUT RESULTS  #

    # Output list of file IDs to STDOUT; pass to curl to download
    json.dump({"ids": file_ids}, sys.stdout)

    # Write requested metadata to .csv file
    with open("file_manifest.csv", "w") as file:
        file.write("file," + ",".join(file_metadata) + "\n")
        for key, values in files.items():
            # Strip file extension from file name
            key = re.split("\.", key)[0]
            annotations = ",".join([str(value) if value else "NA"
                                    for value in list(values.values())])
            file.write(key + "," + annotations + '\n')

############
# Functions:


def op_equals(field, value):
    """Generate JSON for "=" search term"""
    out = {"op": "=",
           "content": {"field": field, "value": [value]}}
    return out


def op_and(content):
    """Generate JSON for "and" operator"""
    out = {"op": "and",
           "content": content}
    return out


def op_in(field, value):
    """Generate JSON for "in" search term"""
    out = {"op": "in",
           "content": {"field": field, "value": value}}
    return out


def get_values(rsp, key, fields=[]):
    """Processes HTML GET/POST response, presents data as dictionary

    rsp: response object from "requests" package
    key: The name of the variable to use as the key for the dict
    [fields]: The fields to return as values in the dict
        if no fields, return list of keys instead of dict"""
    out = {}
    for hit in json.loads(rsp.content)["data"]["hits"]:
        hit_id = hit
        for k in key.split("."):
            hit_id = hit_id[k]
        out[hit_id] = {}
        for field in fields:
            hit_working = hit
            for f in field.split("."):
                hit_working = strip_list(hit_working)[f]
            out[hit_id][f] = hit_working
    if fields:
        return out
    else:
        return list(out.keys())


def strip_list(lst):
    """Un-lists single item lists"""
    if isinstance(lst, list):
        lst = lst[0]
    return lst


if __name__ == "__main__":
    main()
