import os, subprocess
from pathlib import Path
from pywps import Service, Process, LiteralInput, \
    ComplexOutput, BoundingBoxInput, Format
from pywps.app.exceptions import ProcessError
from pywps.response.status import WPS_STATUS
from pywps.validator.mode import MODE
import json, html

__author__ = 'www.github.com/Theropod'


class PCmodel(Process):
    def __init__(self):
        flask_base_path = str(Path(__file__).parent.parent)
        inputs = [LiteralInput('analysis_start_year', 'Analysis start year',
                               abstract='The year when the analysis starts.',
                               data_type='integer',
                               mode=MODE.STRICT,
                               min_occurs=0,
                               default=2020),
                  LiteralInput('analysis_end_year', 'Analysis end year',
                               abstract='The year when the analysis ends.',
                               data_type='integer',
                               mode=MODE.STRICT,
                               min_occurs=0,
                               default=2100),
                  LiteralInput('input_model_file', 'Input model file path',
                               abstract='Path of the climate model file to run pc model on.',
                               data_type='string',
                               mode=MODE.STRICT,
                               min_occurs=0,
                               default=flask_base_path + '/data/pc_model/mrfso_Lmon_CanESM5_ssp126_r16i1p2f1_gn_201501-210012.nc'),
                  LiteralInput('model_name', 'Input model name',
                               abstract='Name of the climate model.',
                               data_type='string',
                               mode=MODE.STRICT,
                               min_occurs=0,
                               default='CanESM5'),
                  LiteralInput('model_var', 'Model file variable',
                               abstract='The Variable in input model data.',
                               data_type='string',
                               mode=MODE.STRICT,
                               min_occurs=0,
                               default='mrfso'),
                  BoundingBoxInput('bbox', 'BBOX for pcmodel analysis',
                                   abstract='The Bounding box for pcmodel analysis data.',
                                   crss=['epsg:4326'],
                                   min_occurs=0,
                                   # lower left and upper right. W S E N
                                   default=[-180, 0, 180, 90]),
                  ]
        outputs = [ComplexOutput('pcmodel_out', 'pcmodel result file',
                                 supported_formats=[
                                     Format('application/json')
                                 ])]

        super(PCmodel, self).__init__(
            self._handler,
            identifier='pc_model',
            version='0.1',
            title='PC model process',
            abstract='The process returns the result of pc model, using NCL',
            profile='',
            inputs=inputs,
            outputs=outputs,
            store_supported=True,
            status_supported=True
        )

    def _handler(self, request, response):
        try:
            # base path of the flask application
            flask_base_path = str(Path(__file__).parent.parent)
            # set environment variables for the NCL script
            pcmodel_env = os.environ.copy()
            # environment variables from input, must be string?
            pcmodel_env['analyse_start_year'] = str(request.inputs['analysis_start_year'][0].data)
            pcmodel_env['analyse_end_year'] = str(request.inputs['analysis_end_year'][0].data)
            pcmodel_env['input_model_file'] = request.inputs['input_model_file'][0].data
            pcmodel_env['modelvar'] = request.inputs['model_var'][0].data
            pcmodel_env['model_name'] = request.inputs['model_name'][0].data
            pcmodel_env['lonW'] = str(request.inputs['bbox'][0].data[0])
            pcmodel_env['latS'] = str(request.inputs['bbox'][0].data[1])
            pcmodel_env['lonE'] = str(request.inputs['bbox'][0].data[2])
            pcmodel_env['latN'] = str(request.inputs['bbox'][0].data[3])
            # environment variables that doesn't change
            # number of models involved in the pcmodel script
            pcmodel_env['model_number'] = '1'
            # whether or not to write out the plotted picture and data
            pcmodel_env['write_plot'] = '1'
            pcmodel_env['write_data'] = '1'
            pcmodel_env['out_plot_type'] = 'png'  # plot picture filetype
            pcmodel_env['work_dir'] = flask_base_path + \
                '/data/pc_model'  # where the NCL script locates
            # data output dir, didn't use pywps flask default self.workdir which locates in /tmp
            pcmodel_env['out_data_dir'] = flask_base_path + '/outputs/pc_model'
            pcmodel_env['out_plot_dir'] = pcmodel_env['out_data_dir']
            # mean of analyzed field is not removed before EOF analysis
            pcmodel_env['ynrmvmean'] = '1'
            pcmodel_env['neof'] = '1'  # The number of EOF modes
            # covariance matrix (0) correlation matrix (1) in EOF analysis
            pcmodel_env['jopt'] = '1'
            # run script and update response
            ncl_command = 'ncl ' + pcmodel_env['work_dir'] + '/pc_model.ncl'
            response.update_status(
                'PyWPS Process pcmodel NCL script started.' + ncl_command, 1)
            print('Pywps NCL script started: ' + ncl_command)
            # run through subprocess
            # execute through shell, timeout is 1 minute, stdout is captured, use default encoding and need not to decode the original bytes
            result = subprocess.run(ncl_command, env=pcmodel_env, shell=True,
                                    capture_output=True, timeout=60, universal_newlines=True)
            # shell error
            if result.stderr:
                # raise pywps.app.exceptions.ProcessError when encounters error in shell script.
                # prints stdout and stderr (if captured, it is not printed)
                failed_message = 'PyWPS Process pcmodel NCL script failed with error.'
                print(failed_message + '\n stderr output: \n' + result.stderr + '\n stdout output:' + result.stdout)
                # to raise a generic pywps internal exception. https://pywps.readthedocs.io/en/latest/api.html#pywps.app.exceptions.ProcessError
                raise ProcessError(failed_message)
            # NCL error
            if result.stdout:
                # raise pywps.app.exceptions.ProcessError when encounters error in NCL.
                # NCL returns no error or status code in subprocess when fatal error occurs, therefore we scan the returning stdout for 'fatal'
                if ('fatal' in result.stdout):
                    # prints stdout (if captured, it is not printed)
                    failed_message = 'PyWPS Process pcmodel NCL script failed with fatal error.'
                    print(failed_message + '\n NCL output: \n' + result.stdout)
                    # to raise a generic pywps internal exception. https://pywps.readthedocs.io/en/latest/api.html#pywps.app.exceptions.ProcessError
                    raise ProcessError(failed_message)
                else:
                    # no error
                    success_message = 'PyWPS Process pcmodel NCL script completed.'
                    # prints stdout (if captured, it is not printed)
                    print(success_message + '\n NCL output: \n' + result.stdout)
                    # # this update status is only called by pywps internally. see https://github.com/geopython/pywps/blob/main/pywps/response/execute.py
                    # response._update_status(WPS_STATUS.SUCCEEDED, success_message, 100)
                    # returns the link of the picture and the nc file
                    resultpath_plot = pcmodel_env['out_plot_dir'] + '/' + pcmodel_env['analyse_start_year'] + \
                        '-' + pcmodel_env['analyse_end_year'] + \
                        '-annual-PC-CanESM5.png'
                    resultpath_nc = pcmodel_env['out_data_dir'] + '/' + pcmodel_env['analyse_start_year'] + \
                        '-' + pcmodel_env['analyse_end_year'] + \
                        '-annual-PC-CanESM5.nc'
                    out_data = {
                        'status': 'completed',
                        'message': success_message,
                        'data': [
                            {
                                'name': 'NCL process output',
                                'value': result.stdout
                            },
                            {
                                'name': 'plot result output path',
                                'value': resultpath_plot
                            },
                            {
                                'name': 'nc result output path',
                                'value': resultpath_nc
                            }
                        ]
                    }
                    # dump to json and escape special characters. If characters are not escaped, the xml result will encounter parse error in browser
                    out_bytes = html.escape(json.dumps(out_data, indent=2))
                    response.outputs['pcmodel_out'].data = out_bytes
                    return response
        except ProcessError as e:
            # see http://docs.opengeospatial.org/is/14-065/14-065.html#61, 9.9.3.
            # NCL errors need to be shown in status info and get result operations, under both synchronous and asynchronous requests.
            # returns the link of the picture and the nc file
            out_data = {
                'status': 'failed',
                'message': e.msg,
                'data': [
                    {
                        'name': 'shell stderr output',
                        'value': result.stderr
                    },
                    {
                        'name': 'NCL stdout',
                        'value': result.stdout
                    }
                ]
            }
            # dump to json and escape special characters. If characters are not escaped, the xml result will encounter parse error in browser
            out_bytes = html.escape(json.dumps(out_data, indent=2))
            # _update should be called internally by pywps, update_status should be callled by processes
            # but update_status cannot represent failure, when NCL or shell script fails, it will still reture wps success result in response
            # https://github.com/geopython/pywps/blob/main/pywps/response/execute.py
            response._update_status(WPS_STATUS.FAILED, out_bytes, 10)

# main function is used to test the process from pywps internally(debug this file)
# to test the wps from GET/POST requests, see buffer process in ../../tests/test_execute.py
def main():
    """Example of how to debug this process, executing it outside a PyWPS 
       instance.
    """
    # see https://github.com/geopython/pywps/blob/main/tests/test_execute.py
    my_pc_model_process = PCmodel()
    service = Service(processes=[my_pc_model_process])

    # successful request test
    class SuccessRequest():
        identifier = 'pc_model'
        service = 'wps'
        operation = 'execute'
        version = '1.0.0'
        raw = True,
        inputs = {
            'analysis_start_year': [{'identifier': 'analysis_start_year', 'data': 2020}],
            'analysis_end_year': [{'identifier': 'analysis_end_year', 'data': 2100}],
            'input_model_file': [{'identifier': 'input_model_file', 'data': str(Path(__file__).parent.parent) + '/data/pc_model/mrfso_Lmon_CanESM5_ssp126_r16i1p2f1_gn_201501-210012.nc'}],
            'model_name': [{'identifier': 'model_name', 'data': 'CanESM5'}],
            'model_var': [{'identifier': 'model_var', 'data': 'mrfso'}],
            'bbox': [{'identifier': 'bbox', 'data': [-180, 0, 180, 90] }]  # lower left and upper right. W S E N
        }
        store_execute = False
        lineage = False
        outputs = ['conventions']
        language = "en-US"
    successrequest = SuccessRequest()
    response = service.execute('pc_model', successrequest, 'fakeuuid')
    # literal_in = count.inputs[0]
    # literal_in.file = '../data/railroads.gml'
    # request.inputs["layer"].append(literal_in)
    print(response.outputs['pcmodel_out'].data) 
    assert response.status == 4
    assert response.status_percentage == 100
    print("Run success")

    #  ncl error test
    class NCLErrorRequest():
        identifier = 'pc_model'
        service = 'wps'
        operation = 'execute'
        version = '1.0.0'
        raw = True
        inputs = {
            'analysis_start_year': [{'identifier': 'analysis_start_year', 'data': 2021}],
            'analysis_end_year': [{'identifier': 'analysis_end_year', 'data': 2060}],
            'input_model_file': [{'identifier': 'input_model_file', 'data': 'test wrong name'}],
            'model_name': [{'identifier': 'model_name', 'data': 'CanESM5'}],
            'model_var': [{'identifier': 'model_var', 'data': 'mrfso'}],
            'bbox': [{'identifier': 'bbox', 'data': [-120, 60, 120, 90] }]  # lower left and upper right. W S E N
        }
        store_execute = False
        lineage = False
        outputs = ['conventions']
        language = "en-US"
    ncl_error_request = NCLErrorRequest()
    response = service.execute('pc_model', ncl_error_request, 'fakeuuid')
    # literal_in = count.inputs[0]
    # literal_in.file = '../data/railroads.gml'
    # request.inputs["layer"].append(literal_in)
    print(response.outputs['pcmodel_out'].data) 
    assert response.status == 5
    assert response.status_percentage == 10
    print("NCL Error captured")


if __name__ == "__main__":
    main()
