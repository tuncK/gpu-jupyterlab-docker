FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

USER root

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update --yes && \
    # - apt-get upgrade is run to patch known vulnerabilities in apt-get packages as
    #   the ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # - bzip2 is necessary to extract the micromamba executable.
    bzip2 \
    ca-certificates \
    fonts-liberation \
    locales \
    # - pandoc is used to convert notebooks to html files
    #   it's not present in aarch64 ubuntu image, so we install it here
    pandoc \
    # - run-one - a wrapper script that runs no more
    #   than one unique  instance  of  some  command with a unique set of arguments,
    #   we use `run-one-constantly` to support `RESTARTABLE` option
    run-one \
    sudo \
    # - tini is installed as a helpful container entrypoint that reaps zombie
    #   processes and such of the actual executable we want to start, see
    #   https://github.com/krallin/tini#why-tini for details.
    tini \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
# hadolint ignore=SC2016
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
   # Add call to conda init script see https://stackoverflow.com/a/58081608/4413446
   echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

USER ${NB_UID}

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
     /bin/bash ~/miniconda.sh -f -b -p /opt/conda && rm -rf ~/miniconda.sh

ENV CONDA_DIR /opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN conda --version

RUN conda install -y -q -c conda-forge -c bioconda mamba

# Python packages
#RUN pip install --no-cache-dir \
#    "colabfold[alphafold] @ git+https://github.com/sokrypton/ColabFold" \
#    onnx \
#    onnx-tf \
#    tf2onnx \
#    skl2onnx \
#    scikit-image \
#    opencv-python \
#    nibabel \
#    onnxruntime \
#    bioblend \
#    numba \
#    aquirdturtle_collapsible_headings

RUN mamba install -y -q -c conda-forge -c bioconda \
    jupyterlab-nvdashboard \
    jupyter_server==1.15.0 \
    jupyterlab \
    jupyter_bokeh \
    nbclassic \
    jupyterlab-git \
    jupytext \
    jupyterlab_execute_time \
    xeus-python \
    jupyterlab-kernelspy \
    jupyterlab-system-monitor \
    jupyterlab-topbar \
    matplotlib \
    seaborn \
    #"elyra[all]" \
    voila \
    bioblend \
    galaxy-ie-helpers \
    bqplot

RUN pip install \
    bioblend \
    galaxy-ie-helpers \
    tensorflow-gpu==2.7.0 \
    tensorflow_probability==0.15.0

#RUN mamba install -y -q -c conda-forge -c bioconda kalign2=2.04 hhsuite=3.3.0

#RUN pip install --upgrade jax==0.3.10 jaxlib==0.3.10 -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

USER root 

ADD ./startup.sh /startup.sh
ADD ./get_notebook.py /get_notebook.py


RUN mkdir -p /home/$NB_USER/.ipython/profile_default/startup/
RUN mkdir /import

COPY ./galaxy_script_job.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
COPY ./ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/01-load.py
#COPY ./jupyter_notebook_config.py /home/$NB_USER/.jupyter/
COPY ./jupyter_notebook_config.py /home/$NB_USER/.jupyter/
#COPY ./jupyter_lab_config.py /home/$NB_USER/.jupyter/

ADD ./*.ipynb /home/$NB_USER/

RUN mkdir /home/$NB_USER/notebooks/
RUN mkdir /home/$NB_USER/usecases/
RUN mkdir /home/$NB_USER/elyra/

COPY ./notebooks/*.ipynb /home/$NB_USER/notebooks/
COPY ./usecases/*.ipynb /home/$NB_USER/usecases/
COPY ./elyra/*.* /home/$NB_USER/elyra/

RUN mkdir /home/$NB_USER/data
COPY ./data/*.tsv /home/$NB_USER/data/


# ENV variables to replace conf file
ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    DISABLE_AUTH=true \
    GALAXY_URL=none

RUN chown -R $NB_USER:users /home/$NB_USER /import

USER ${NB_UID}

WORKDIR /import

CMD /startup.sh
